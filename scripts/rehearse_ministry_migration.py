"""Deterministic, synthetic-only rehearsal for the future ministry import."""

import argparse
import json
from pathlib import Path
import sys
from uuid import NAMESPACE_URL, uuid5

_ENTITIES = (
    "congregations",
    "contacts",
    "students",
    "classes",
    "enrollments",
    "sessions",
    "attendance",
    "progress",
    "converts",
    "links",
)
_SOURCES = {"firebase", "base44"}
_ROW_KEYS = {
    "entity",
    "source_system",
    "source_id",
    "source_state",
    "congregation_candidates",
    "existing_student_candidates",
}
_STABLE_NAMESPACE = uuid5(NAMESPACE_URL, "https://ieadpe.example/synthetic-ministry-migration/v1")

def build_report(payload):
    if set(payload) != {"records"} or not isinstance(payload["records"], list):
        raise ValueError("input must contain only a records array")

    seen = set()
    rows = []
    for record in payload["records"]:
        if not isinstance(record, dict) or set(record) - _ROW_KEYS:
            raise ValueError("record contains unsupported fields")
        entity = record.get("entity")
        source = record.get("source_system")
        source_id = record.get("source_id")
        source_state = record.get("source_state")
        congregation_candidates = record.get("congregation_candidates")
        student_candidates = record.get("existing_student_candidates")
        if entity not in _ENTITIES or source not in _SOURCES:
            raise ValueError("unsupported entity or source_system")
        if not all(isinstance(value, str) and value.strip() for value in (source_id, source_state)):
            raise ValueError("source_id and source_state must be non-empty strings")
        if not isinstance(congregation_candidates, list) or not all(
            isinstance(value, str) and value.strip() for value in congregation_candidates
        ):
            raise ValueError("congregation_candidates must be a list of canonical IDs")
        if student_candidates is not None and (
            not isinstance(student_candidates, list)
            or not all(isinstance(value, str) and value.strip() for value in student_candidates)
        ):
            raise ValueError("existing_student_candidates must be a list of canonical IDs")

        source_key = f"{source}:{entity}:{source_id}"
        if source_key in seen:
            raise ValueError(f"duplicate source key: {source_key}")
        seen.add(source_key)
        review_reason = None
        if not congregation_candidates:
            review_reason = "congregation_unmatched"
        elif len(congregation_candidates) > 1:
            review_reason = "congregation_ambiguous"
        elif student_candidates is not None and not student_candidates:
            review_reason = "student_unmatched"
        elif student_candidates is not None and len(student_candidates) > 1:
            review_reason = "student_ambiguous"

        rows.append(
            {
                "entity": entity,
                "source_system": source,
                "source_id": source_id,
                "source_key": source_key,
                "target_id": str(uuid5(_STABLE_NAMESPACE, source_key)),
                "source_state": source_state,
                "resolved_congregation_id": congregation_candidates[0]
                if len(congregation_candidates) == 1
                else None,
                "resolved_student_id": student_candidates[0]
                if student_candidates is not None and len(student_candidates) == 1
                else None,
                "status": "review" if review_reason else "ready",
                "review_reason": review_reason,
            }
        )

    rows.sort(key=lambda row: (row["entity"], row["source_system"], row["source_id"]))
    source_counts = {entity: 0 for entity in _ENTITIES}
    mapped_counts = {entity: 0 for entity in _ENTITIES}
    source_states = {entity: {} for entity in _ENTITIES}
    mapped_states = {entity: {} for entity in _ENTITIES}
    for row in rows:
        entity = row["entity"]
        source_counts[entity] += 1
        mapped_counts[entity] += 1
        source_states[entity][row["source_state"]] = source_states[entity].get(row["source_state"], 0) + 1
        mapped_states[entity][row["source_state"]] = mapped_states[entity].get(row["source_state"], 0) + 1

    links = [
        {"source_key": row["source_key"], "target_id": row["target_id"], "status": row["status"]}
        for row in rows
        if row["entity"] == "links"
    ]
    return {
        "format_version": 1,
        "mode": "synthetic_dry_run_only",
        "rows": rows,
        "links": links,
        "review_count": sum(row["status"] == "review" for row in rows),
        "reconciliation": {
            "source_counts": source_counts,
            "mapped_counts": mapped_counts,
            "source_states": source_states,
            "mapped_states": mapped_states,
            "counts_match": source_counts == mapped_counts,
            "states_match": source_states == mapped_states,
        },
    }


def run_cli(argv=None):
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True)
    parser.add_argument("--output", required=True)
    args = parser.parse_args(argv)
    payload = json.loads(Path(args.input).read_text(encoding="utf-8"))
    report = build_report(payload)
    replay = build_report(payload)
    if report != replay:
        raise RuntimeError("repeat rehearsal changed counts, mappings or links")
    Path(args.output).write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print("PASS: synthetic rehearsal report written", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(run_cli())
