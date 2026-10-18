"""Validate a Base44 backup and build a one-use SQL transaction without logging its data."""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import pathlib
import re
import sys


FORMAT = "ieadpe-converts-full-backup"
ENTITY_NAMES = ("Congregation", "Convert", "ConvertEvent", "WeeklyReport", "UserAccess", "Feedback")
ENTITY_TABLES = {
    "Congregation": ("public.congregations", "congregation"),
    "Convert": ("public.converts", "convert"),
    "ConvertEvent": ("public.convert_events", "event"),
    "WeeklyReport": ("public.weekly_reports", "weekly_report"),
    "UserAccess": ("private.base44_user_access_pending", "user_access"),
    "Feedback": ("private.base44_feedback_archive", "feedback"),
}
ROLES = {"Membro da direção da campanha", "Membro da supervisão das campanhas"}
EVENT_TYPES = {"visit", "discipleship_started", "discipleship_completed", "deviated"}
TRUTHY = {True, 1}


def validate(value: object) -> tuple[dict, dict[str, int], int]:
    if not isinstance(value, dict) or value.get("format") != FORMAT:
        raise ValueError("unsupported backup format")
    if value.get("format_version") != 1 or value.get("completed") is not True:
        raise ValueError("incomplete or unsupported backup")
    data = value.get("data")
    if not isinstance(data, dict) or set(data) != set(ENTITY_NAMES):
        raise ValueError("backup entity set mismatch")
    counts: dict[str, int] = {}
    ids: dict[str, set[str]] = {}
    for entity in ENTITY_NAMES:
        rows = data[entity]
        if not isinstance(rows, list):
            raise ValueError("invalid entity rows")
        counts[entity] = len(rows)
        ids[entity] = set()
        for row in rows:
            if not isinstance(row, dict) or not isinstance(row.get("id"), str) or not row["id"].strip():
                raise ValueError("missing source ID")
            if row["id"] in ids[entity]:
                raise ValueError("duplicate source ID")
            ids[entity].add(row["id"])
            if row.get("is_sample") is not False:
                raise ValueError("sample or unclassified row")
            for key in ("created_date", "updated_date", "created_by_id", "created_by", "is_sample"):
                if key not in row:
                    raise ValueError("source metadata missing")
    congregation_ids = ids["Congregation"]
    for row in data["Congregation"]:
        if not isinstance(row.get("name"), str) or not row["name"].strip():
            raise ValueError("invalid congregation")
    names = [row["name"].strip().casefold() for row in data["Congregation"]]
    if len(names) != len(set(names)):
        raise ValueError("ambiguous congregation names")
    for row in data["Convert"]:
        if any(not isinstance(row.get(key), str) or not row[key].strip() for key in
               ("name", "landmark", "conversion_date", "worship_type")):
            raise ValueError("convert required field missing")
        if row.get("gender") not in {"male", "female"}:
            raise ValueError("invalid gender")
        if row.get("congregation_id") not in congregation_ids:
            raise ValueError("unresolved convert congregation")
        for key in ("conversion_date", "last_visit_date", "discipleship_start_date"):
            if row.get(key) is not None:
                try:
                    parsed = dt.date.fromisoformat(row[key])
                except (TypeError, ValueError) as exc:
                    raise ValueError("invalid convert date") from exc
                if key == "conversion_date" and parsed > dt.date.today():
                    raise ValueError("future conversion date")
        if row.get("age") is not None and (not isinstance(row["age"], int) or not 0 <= row["age"] <= 150):
            raise ValueError("invalid convert age")
        visit_count = row.get("visit_count")
        if visit_count is not None and (not isinstance(visit_count, int) or visit_count < 0):
            raise ValueError("invalid visit count")
    for row in data["ConvertEvent"]:
        if row.get("congregation_id") not in congregation_ids or row.get("event_type") not in EVENT_TYPES:
            raise ValueError("invalid event reference or type")
        try:
            dt.date.fromisoformat(row["event_date"])
        except (TypeError, ValueError) as exc:
            raise ValueError("invalid event date") from exc
    for row in data["WeeklyReport"]:
        if row.get("congregation_id") not in congregation_ids:
            raise ValueError("invalid weekly report congregation")
        if not isinstance(row.get("confirmed_by_email"), str) or not row["confirmed_by_email"].strip():
            raise ValueError("invalid weekly report confirmer")
        try:
            monday = dt.date.fromisoformat(row["week_start"])
        except (TypeError, ValueError) as exc:
            raise ValueError("invalid weekly report date") from exc
        if monday.isoweekday() != 1:
            raise ValueError("weekly report date must be Monday")
    for row in data["UserAccess"]:
        role = row.get("role")
        scope = row.get("congregation_id")
        valid_scope = (role == "Membro da supervisão das campanhas" and scope is None) or (
            role == "Membro da direção da campanha" and scope in congregation_ids
        )
        if (not isinstance(row.get("user_email"), str) or "@" not in row["user_email"] or
                role not in ROLES or not valid_scope):
            raise ValueError("invalid pending access row")
    orphan_events = sum(row["convert_id"] not in ids["Convert"] for row in data["ConvertEvent"])
    normalizations = {
        "congregation_name": sum(row["name"] != row["name"].strip() for row in data["Congregation"]),
        "convert_name": sum(row["name"] != row["name"].strip() for row in data["Convert"]),
        "landmark": sum(row["landmark"] != row["landmark"].strip() for row in data["Convert"]),
        "worship_type": sum(row["worship_type"] != row["worship_type"].strip() for row in data["Convert"]),
    }
    return data, counts, orphan_events, normalizations


def _sql_literal(value: str) -> str:
    return "'" + value.replace("'", "''") + "'"


def build(source: pathlib.Path, output: pathlib.Path, dry_run: bool = False) -> dict:
    raw = source.read_bytes()
    value = json.loads(raw)
    data, counts, orphan_events, normalizations = validate(value)
    digest = hashlib.sha256(raw).hexdigest()
    payload = json.dumps(value, ensure_ascii=False, separators=(",", ":"))
    delimiter = "$base44_" + digest[:16] + "$"
    if delimiter in payload:
        raise ValueError("unexpected SQL delimiter in source")
    expected = json.dumps(counts, ensure_ascii=False, separators=(",", ":"))
    expected_literal = _sql_literal(expected)
    digest_literal = _sql_literal(digest)
    payload_sql = f"{delimiter}{payload}{delimiter}::jsonb"

    metadata_sql = "\nUNION ALL\n".join(
        f"SELECT {_sql_literal(entity)}, r->>'id', r->>'created_by_id', r->>'created_by', "
        f"(r->>'is_sample')::boolean, r->>'created_date', r->>'updated_date' "
        f"FROM jsonb_array_elements(backup->'data'->{_sql_literal(entity)}) r"
        for entity in ENTITY_NAMES
    )
    sql = f"""BEGIN;
DO $base44_import$
DECLARE
 backup jsonb := {payload_sql};
 digest text := {digest_literal};
 expected_counts jsonb := {expected_literal}::jsonb;
 imported_count integer;
 linked_event_count integer;
 orphan_event_count integer;
BEGIN
 IF backup->>'format'<>{_sql_literal(FORMAT)} OR (backup->>'format_version')::integer<>1 OR backup->>'completed'<>'true' THEN
  RAISE EXCEPTION 'invalid_base44_export';
 END IF;
 IF EXISTS(SELECT FROM private.base44_migration_imports WHERE source='base44' AND export_digest=digest) THEN
  RAISE NOTICE 'Base44 export digest already imported; no changes applied';
  RETURN;
 END IF;
 IF EXISTS(SELECT FROM public.congregations WHERE legacy_base44_id IN
   (SELECT r->>'id' FROM jsonb_array_elements(backup->'data'->'Congregation') r)) OR
  EXISTS(SELECT FROM public.converts WHERE legacy_base44_id IN
   (SELECT r->>'id' FROM jsonb_array_elements(backup->'data'->'Convert') r)) OR
  EXISTS(SELECT FROM public.convert_events WHERE legacy_base44_id IN
   (SELECT r->>'id' FROM jsonb_array_elements(backup->'data'->'ConvertEvent') r)) OR
  EXISTS(SELECT FROM public.weekly_reports WHERE legacy_base44_id IN
   (SELECT r->>'id' FROM jsonb_array_elements(backup->'data'->'WeeklyReport') r)) OR
  EXISTS(SELECT FROM private.base44_user_access_pending WHERE legacy_base44_id IN
   (SELECT r->>'id' FROM jsonb_array_elements(backup->'data'->'UserAccess') r)) OR
  EXISTS(SELECT FROM private.base44_feedback_archive WHERE legacy_base44_id IN
   (SELECT r->>'id' FROM jsonb_array_elements(backup->'data'->'Feedback') r)) THEN
  RAISE EXCEPTION 'base44_source_key_conflict';
 END IF;

 INSERT INTO public.congregations(id,legacy_base44_id,name,created_at)
 SELECT private.base44_stable_uuid('Congregation',r->>'id'),r->>'id',btrim(r->>'name'),
  coalesce((r->>'created_date')::timestamptz,now())
 FROM jsonb_array_elements(backup->'data'->'Congregation') r;

 INSERT INTO public.converts(id,internal_id,legacy_base44_id,name,landmark,gender,conversion_date,worship_type,
  congregation_id,photo_url,address,phone,age,last_visit_date,was_visited_once,visit_count,is_in_discipleship,
  discipleship_start_date,is_discipleship_completed,is_deviated,created_by,created_at,updated_at)
 SELECT private.base44_stable_uuid('Convert',r->>'id'),r->>'id',r->>'id',btrim(r->>'name'),btrim(r->>'landmark'),r->>'gender',
  (r->>'conversion_date')::date,btrim(r->>'worship_type'),private.base44_stable_uuid('Congregation',r->>'congregation_id'),
  nullif(r->>'photo_url',''),nullif(r->>'address',''),nullif(r->>'phone',''),nullif(r->>'age','')::integer,
  nullif(r->>'last_visit_date','')::date,coalesce((r->>'was_visited_once')::boolean,false),
  coalesce(nullif(r->>'visit_count','')::integer,0),coalesce((r->>'is_in_discipleship')::boolean,false),
  nullif(r->>'discipleship_start_date','')::date,coalesce((r->>'is_discipleship_completed')::boolean,false),
  coalesce((r->>'is_deviated')::boolean,false),null,coalesce((r->>'created_date')::timestamptz,now()),
  coalesce((r->>'updated_date')::timestamptz,(r->>'created_date')::timestamptz,now())
 FROM jsonb_array_elements(backup->'data'->'Convert') r;

 WITH affected_weeks AS (
  SELECT DISTINCT private.base44_stable_uuid('Congregation',r->>'congregation_id') AS congregation_id,
   date_trunc('week',(r->>'conversion_date')::date)::date AS week_start
  FROM jsonb_array_elements(backup->'data'->'Convert') r
 )
 INSERT INTO private.congregation_week_guards(congregation_id,week_start,conversion_count)
 SELECT c.congregation_id,w.week_start,count(*)::integer
 FROM affected_weeks w JOIN public.converts c ON c.congregation_id=w.congregation_id
  AND c.conversion_date BETWEEN w.week_start AND w.week_start+6
 WHERE c.deleted_at IS NULL
 GROUP BY c.congregation_id,w.week_start
 ON CONFLICT(congregation_id,week_start) DO UPDATE SET conversion_count=excluded.conversion_count;

 INSERT INTO public.convert_events(id,legacy_base44_id,convert_id,legacy_convert_id,convert_name,congregation_id,
  event_type,event_date,done_by_email,created_by,created_at)
 SELECT private.base44_stable_uuid('ConvertEvent',r->>'id'),r->>'id',
  CASE WHEN EXISTS(SELECT FROM jsonb_array_elements(backup->'data'->'Convert') c WHERE c->>'id'=r->>'convert_id')
   THEN private.base44_stable_uuid('Convert',r->>'convert_id') ELSE NULL END,
  CASE WHEN EXISTS(SELECT FROM jsonb_array_elements(backup->'data'->'Convert') c WHERE c->>'id'=r->>'convert_id')
   THEN NULL ELSE r->>'convert_id' END,
  r->>'convert_name',private.base44_stable_uuid('Congregation',r->>'congregation_id'),r->>'event_type',
  (r->>'event_date')::date,nullif(r->>'done_by_email',''),null,
  coalesce((r->>'created_date')::timestamptz,now())
 FROM jsonb_array_elements(backup->'data'->'ConvertEvent') r;

 INSERT INTO public.weekly_reports(id,legacy_base44_id,congregation_id,week_start,confirmed_by_email,confirmed_by_name,created_by,created_at)
 SELECT private.base44_stable_uuid('WeeklyReport',r->>'id'),r->>'id',
  private.base44_stable_uuid('Congregation',r->>'congregation_id'),(r->>'week_start')::date,
  r->>'confirmed_by_email',nullif(r->>'confirmed_by_name',''),null,
  coalesce((r->>'created_date')::timestamptz,now())
 FROM jsonb_array_elements(backup->'data'->'WeeklyReport') r;

 INSERT INTO private.base44_user_access_pending(legacy_base44_id,user_email,role,congregation_id,
  legacy_congregation_id,created_at,updated_at,import_digest)
 SELECT r->>'id',r->>'user_email',r->>'role',
  CASE WHEN r->>'congregation_id' IS NULL THEN NULL ELSE private.base44_stable_uuid('Congregation',r->>'congregation_id') END,
  r->>'congregation_id',nullif(r->>'created_date','')::timestamptz,
  nullif(r->>'updated_date','')::timestamptz,digest
 FROM jsonb_array_elements(backup->'data'->'UserAccess') r;

 INSERT INTO private.base44_feedback_archive(legacy_base44_id,source_record,import_digest)
 SELECT r->>'id',r,digest
 FROM jsonb_array_elements(backup->'data'->'Feedback') r;

 INSERT INTO private.base44_source_metadata(entity_name,legacy_base44_id,created_by_id,created_by,is_sample,
  source_created_date,source_updated_date,import_digest)
 SELECT m.entity,m.source_id,m.creator_id,m.creator,m.sample,m.created,m.updated,digest
 FROM ({metadata_sql}) m(entity,source_id,creator_id,creator,sample,created,updated);

 SELECT count(*) INTO linked_event_count FROM public.convert_events
  WHERE legacy_base44_id IN (SELECT r->>'id' FROM jsonb_array_elements(backup->'data'->'ConvertEvent') r) AND convert_id IS NOT NULL;
 SELECT count(*) INTO orphan_event_count FROM public.convert_events
  WHERE legacy_base44_id IN (SELECT r->>'id' FROM jsonb_array_elements(backup->'data'->'ConvertEvent') r) AND convert_id IS NULL;
 IF linked_event_count+orphan_event_count<>(expected_counts->>'ConvertEvent')::integer OR
  (SELECT count(*) FROM public.congregations WHERE legacy_base44_id IS NOT NULL)<>
    (expected_counts->>'Congregation')::integer OR
  (SELECT count(*) FROM public.converts WHERE legacy_base44_id IS NOT NULL)<>
    (expected_counts->>'Convert')::integer OR
  (SELECT count(*) FROM public.weekly_reports WHERE legacy_base44_id IS NOT NULL)<>
    (expected_counts->>'WeeklyReport')::integer OR
  (SELECT count(*) FROM private.base44_user_access_pending)<>
    (expected_counts->>'UserAccess')::integer OR
  (SELECT count(*) FROM private.base44_feedback_archive WHERE import_digest=digest)<>
    (expected_counts->>'Feedback')::integer OR
  EXISTS(SELECT FROM jsonb_array_elements(backup->'data'->'Convert') r
   WHERE NOT EXISTS(SELECT FROM private.congregation_week_guards g
    WHERE g.congregation_id=private.base44_stable_uuid('Congregation',r->>'congregation_id')
     AND g.week_start=date_trunc('week',(r->>'conversion_date')::date)::date
     AND g.conversion_count=(SELECT count(*) FROM public.converts c
      WHERE c.congregation_id=g.congregation_id
       AND c.conversion_date BETWEEN g.week_start AND g.week_start+6 AND c.deleted_at IS NULL))) OR
  EXISTS(SELECT FROM public.user_access WHERE user_email IN
    (SELECT r->>'user_email' FROM jsonb_array_elements(backup->'data'->'UserAccess') r)) OR
  (SELECT count(*) FROM private.base44_source_metadata WHERE import_digest=digest)<>
    ((expected_counts->>'Congregation')::integer+(expected_counts->>'Convert')::integer+
     (expected_counts->>'ConvertEvent')::integer+(expected_counts->>'WeeklyReport')::integer+
     (expected_counts->>'UserAccess')::integer+(expected_counts->>'Feedback')::integer) THEN
  RAISE EXCEPTION 'base44_reconciliation_failed';
 END IF;
 INSERT INTO private.base44_migration_imports(source,export_digest,record_counts)
 VALUES('base44',digest,expected_counts);
 RAISE NOTICE 'Base44 migration verified: % congregations, % converts, % linked events, % orphan events, % reports, % pending access rows, % feedback rows archived; no active access rows created',
  (expected_counts->>'Congregation')::integer,(expected_counts->>'Convert')::integer,
  linked_event_count,orphan_event_count,(expected_counts->>'WeeklyReport')::integer,
  (expected_counts->>'UserAccess')::integer,(expected_counts->>'Feedback')::integer;
END
$base44_import$;
{"ROLLBACK" if dry_run else "COMMIT"};
"""
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(sql, encoding="utf-8", newline="\n")
    total = sum(counts.values())
    return {"records": total, "orphan_events": orphan_events, "counts": counts,
            "normalizations": normalizations, "digest": digest}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", required=True, type=pathlib.Path)
    parser.add_argument("--output", required=True, type=pathlib.Path)
    parser.add_argument("--dry-run", action="store_true", help="Generate a SQL transaction ending with ROLLBACK")
    args = parser.parse_args()
    try:
        summary = build(args.input, args.output, args.dry_run)
    except (OSError, json.JSONDecodeError, ValueError) as exc:
        print(f"Base44 export rejected: {exc}", file=sys.stderr)
        return 2
    normalized = sum(summary["normalizations"].values())
    print(f"Validated {summary['records']} records; {summary['orphan_events']} orphan events; "
          f"trimmed {normalized} outer-whitespace fields; SQL: {args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
