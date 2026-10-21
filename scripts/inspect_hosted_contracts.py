"""Read-only catalog inventory using a preconfigured managed libpq service.

Credentials are supplied by the operator's managed PGSERVICE channel. This tool
never prints connection settings, invokes application scope RPCs, or writes data.
"""
import argparse
import json
import os
from pathlib import Path
import subprocess
import sys
import re
import ipaddress
import socket

TARGET = "voqmtnqjrbugpazcimvh"
def validate_project_endpoint(project_ref, endpoint):
    if not re.fullmatch(r"[a-z0-9]{20}", project_ref):
        raise ValueError("project-ref must be a 20-character Supabase project ref")
    expected = f"db.{project_ref}.supabase.co"
    if endpoint.lower().rstrip(".") != expected:
        raise ValueError("endpoint does not match the project-ref direct database host")
    return expected


def build_endpoint_conninfo(project_ref, endpoint, hostaddr, service):
    expected = validate_project_endpoint(project_ref, endpoint)
    try:
        address = ipaddress.ip_address(hostaddr)
    except ValueError as exc:
        raise ValueError("hostaddr must be a resolved IP address") from exc
    if not re.fullmatch(r"[A-Za-z0-9_-]{1,63}", service):
        raise ValueError("service name has invalid characters")
    return (f"service={service} host={expected} hostaddr={address.compressed} port=5432 "
            "dbname=postgres sslmode=verify-full sslrootcert=system")


def resolve_endpoint_addresses(endpoint):
    validated = validate_project_endpoint(TARGET, endpoint)
    values = {item[4][0] for item in socket.getaddrinfo(validated, 5432, type=socket.SOCK_STREAM)}
    if not values:
        raise ValueError("endpoint has no resolved addresses")
    return sorted(values, key=lambda value: (ipaddress.ip_address(value).version, value))


def sanitized_libpq_environment(source=None):
    source = os.environ if source is None else source
    return {key: value for key, value in source.items() if not key.upper().startswith("PG")}


CONTRACT_KEYS = ("columns", "constraints", "indexes", "policies", "functions",
                 "rls", "table_grants", "function_grants", "data_invariants")


def classify_migration_version(ledger_recorded, expected_contract, observed_contract):
    if set(expected_contract) != set(CONTRACT_KEYS) or set(observed_contract) != set(CONTRACT_KEYS):
        raise ValueError("migration contracts must cover columns, constraints, indexes, policies, functions, grants and data invariants")
    if any(not isinstance(expected_contract[key], dict) or not isinstance(observed_contract[key], dict)
           for key in CONTRACT_KEYS):
        raise ValueError("every semantic contract category must be an identity-to-fingerprint map")
    exact = all(expected_contract[key] == observed_contract[key] for key in CONTRACT_KEYS)
    present = any(set(expected_contract[key]) & set(observed_contract[key])
                  for key in CONTRACT_KEYS)
    if exact:
        return "recorded+present" if ledger_recorded else "unrecorded+fully-equivalent"
    if not ledger_recorded and not present:
        return "absent"
    return "partial/conflicting"


def validate_contract_document(document):
    """Require an explicit contract for each migration before any network access."""
    from rehearse_hosted_upgrade import migration_sequence
    if not isinstance(document, dict) or not isinstance(document.get("versions"), list):
        raise ValueError("contract document must contain a versions list")
    expected_sequence = [item["version"] for item in migration_sequence()]
    versions = document["versions"]
    if document.get("schema_version") != 1 or not isinstance(document.get("baseline"), dict) or document["baseline"].get("version") != "202610180002":
        raise ValueError("semantic manifest must declare schema version 1 and the 180002 synthetic baseline")
    actual_sequence = []
    source_by_version = {item["version"]: item for item in migration_sequence()}
    for item in versions:
        if not isinstance(item, dict) or not isinstance(item.get("version"), str):
            raise ValueError("each semantic contract requires a version")
        contract = item.get("contract")
        if not isinstance(contract, dict) or set(contract) != set(CONTRACT_KEYS):
            raise ValueError("each migration contract must include all semantic categories")
        if any(not isinstance(contract[key], dict) for key in CONTRACT_KEYS):
            raise ValueError("semantic categories must be identity-to-fingerprint maps")
        if not any(contract[key] for key in CONTRACT_KEYS):
            raise ValueError("each migration contract must name expected semantic effects")
        source = source_by_version.get(item["version"])
        if source is None:
            raise ValueError("contracts must match the exact ordered migration sequence")
        if item.get("source_sha256") != source["sha256"]:
            raise ValueError("semantic manifest source checksum mismatch")
        if not isinstance(item.get("effects"), dict) or not item["effects"]:
            raise ValueError("each migration requires snapshot-derived effects")
        if not isinstance(item.get("lineage"), list) or not item["lineage"]:
            raise ValueError("each migration requires object lineage")
        if not isinstance(item.get("invariants"), dict) or not item["invariants"]:
            raise ValueError("each migration requires synthetic invariant evidence")
        actual_sequence.append(item["version"])
    if actual_sequence != expected_sequence:
        raise ValueError("contracts must match the exact ordered migration sequence")
    return actual_sequence


def classify_inventory(expected_versions, observed_contract, ledger_versions):
    expected_sequence = [item["version"] for item in expected_versions]
    if len(expected_sequence) != len(set(expected_sequence)):
        raise ValueError("duplicate migration version in semantic contract")
    classifications = []
    for item in expected_versions:
        version = item.get("version")
        expected = item.get("contract")
        if not isinstance(version, str) or not isinstance(expected, dict):
            raise ValueError("each semantic contract needs version and contract fields")
        state = classify_migration_version(version in ledger_versions, expected, observed_contract)
        classifications.append({"version": version, "state": state})
    return classifications


CATALOG_SQL = r"""
BEGIN TRANSACTION READ ONLY;
SELECT jsonb_build_object(
 'ledger', coalesce((SELECT jsonb_agg(jsonb_build_object('version', version) ORDER BY version) FROM supabase_migrations.schema_migrations), '[]'::jsonb),
 'capabilities', jsonb_build_object('ministry_people', to_regclass('public.ministry_people') IS NOT NULL),
 'capabilities', jsonb_build_object('ministry_people', to_regclass('public.ministry_people') IS NOT NULL),
 'columns', coalesce((SELECT jsonb_agg(jsonb_build_object('schema', table_schema, 'table', table_name, 'column', column_name, 'type', data_type, 'nullable', is_nullable, 'default_fingerprint', md5(coalesce(column_default,'')), 'generated', is_generated) ORDER BY table_schema, table_name, ordinal_position) FROM information_schema.columns WHERE table_schema IN ('public','private')), '[]'::jsonb),
 'constraints', coalesce((SELECT jsonb_agg(jsonb_build_object('schema', n.nspname, 'table', c.relname, 'name', con.conname, 'definition_fingerprint', md5(pg_get_constraintdef(con.oid, true))) ORDER BY n.nspname,c.relname,con.conname) FROM pg_constraint con JOIN pg_class c ON c.oid=con.conrelid JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname IN ('public','private')), '[]'::jsonb),
 'indexes', coalesce((SELECT jsonb_agg(jsonb_build_object('schema', schemaname, 'table', tablename, 'name', indexname, 'definition_fingerprint', md5(indexdef)) ORDER BY schemaname, tablename, indexname) FROM pg_catalog.pg_indexes WHERE schemaname IN ('public','private')), '[]'::jsonb),
 'policies', coalesce((SELECT jsonb_agg(jsonb_build_object('schema', schemaname, 'table', tablename, 'name', policyname, 'command', cmd, 'roles', roles, 'qual_fingerprint', md5(coalesce(qual,'')), 'check_fingerprint', md5(coalesce(with_check,''))) ORDER BY schemaname, tablename, policyname) FROM pg_policies WHERE schemaname IN ('public','private')), '[]'::jsonb),
 'functions', coalesce((SELECT jsonb_agg(jsonb_build_object('schema', n.nspname, 'name', p.proname, 'identity', pg_get_function_identity_arguments(p.oid), 'definition_fingerprint', md5(pg_get_functiondef(p.oid)), 'security_definer', p.prosecdef) ORDER BY n.nspname,p.proname) FROM pg_catalog.pg_proc p JOIN pg_catalog.pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname IN ('public','private')), '[]'::jsonb),
 'rls', coalesce((SELECT jsonb_agg(jsonb_build_object('schema', n.nspname, 'table', c.relname, 'enabled', c.relrowsecurity, 'forced', c.relforcerowsecurity) ORDER BY n.nspname,c.relname) FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname IN ('public','private') AND c.relkind='r'), '[]'::jsonb),
 'table_grants', coalesce((SELECT jsonb_agg(jsonb_build_object('schema', n.nspname, 'table', c.relname, 'grantee', CASE WHEN a.grantee=0 THEN 'PUBLIC' ELSE pg_get_userbyid(a.grantee) END, 'privilege', upper(a.privilege_type)) ORDER BY n.nspname,c.relname,a.grantee,a.privilege_type) FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace CROSS JOIN LATERAL aclexplode(coalesce(c.relacl, acldefault('r',c.relowner))) a WHERE n.nspname IN ('public','private') AND c.relkind IN ('r','p','v','m','f')), '[]'::jsonb),
 'function_grants', coalesce((SELECT jsonb_agg(jsonb_build_object('routine_schema', n.nspname, 'routine_name', p.proname, 'identity_arguments', pg_get_function_identity_arguments(p.oid), 'grantee', CASE WHEN a.grantee=0 THEN 'PUBLIC' ELSE pg_get_userbyid(a.grantee) END, 'privilege', upper(a.privilege_type)) ORDER BY n.nspname,p.proname,pg_get_function_identity_arguments(p.oid),a.grantee,a.privilege_type) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace CROSS JOIN LATERAL aclexplode(coalesce(p.proacl, acldefault('f',p.proowner))) a WHERE n.nspname IN ('public','private')), '[]'::jsonb),
 'data_invariants', jsonb_build_object(
  'public.converts.total', (SELECT count(*)::bigint FROM public.converts),
  'public.converts.active', (SELECT count(*)::bigint FROM public.converts WHERE deleted_at IS NULL),
  'public.ministry_students.total', (SELECT count(*)::bigint FROM public.ministry_students),
  'private.congregation_week_guards.count', (SELECT count(*)::bigint FROM private.congregation_week_guards),
  'private.congregation_week_guards.missing', (SELECT count(*)::bigint FROM (SELECT c.congregation_id,date_trunc('week',c.conversion_date)::date AS week_start FROM public.converts c WHERE c.deleted_at IS NULL AND c.congregation_id IS NOT NULL GROUP BY c.congregation_id,date_trunc('week',c.conversion_date)::date) x LEFT JOIN private.congregation_week_guards g USING(congregation_id,week_start) WHERE g.congregation_id IS NULL),
  'private.congregation_week_guards.stale', (SELECT count(*)::bigint FROM private.congregation_week_guards g WHERE g.conversion_count IS DISTINCT FROM (SELECT count(*)::integer FROM public.converts c WHERE c.congregation_id=g.congregation_id AND c.conversion_date BETWEEN g.week_start AND g.week_start+6 AND c.deleted_at IS NULL))
 )
)::text;
ROLLBACK;
"""


BACKFILL_CATALOG_SQL = r"""
BEGIN TRANSACTION READ ONLY;
SELECT jsonb_build_object(
 'public.converts.backfill_unlinked', (SELECT count(*)::bigint FROM public.converts WHERE congregation_id IS NOT NULL AND person_id IS NULL),
 'public.converts.backfill_wrong_scope', (SELECT count(*)::bigint FROM public.converts c WHERE c.person_id IS NOT NULL AND NOT EXISTS (SELECT FROM public.ministry_people p WHERE p.id=c.person_id AND p.congregation_id=c.congregation_id)),
 'public.ministry_students.person_wrong_scope', (SELECT count(*)::bigint FROM public.ministry_students s WHERE s.person_id IS NOT NULL AND NOT EXISTS (SELECT FROM public.ministry_people p WHERE p.id=s.person_id AND p.congregation_id=s.congregation_id)),
 'public.ministry_people.count_matches_scoped_converts', ((SELECT count(*) FROM public.ministry_people)=(SELECT count(*) FROM public.converts WHERE congregation_id IS NOT NULL))
)::text;
ROLLBACK;
"""


BACKFILL_CATALOG_SQL = r"""
BEGIN TRANSACTION READ ONLY;
SELECT jsonb_build_object(
 'public.converts.backfill_unlinked', (SELECT count(*)::bigint FROM public.converts WHERE congregation_id IS NOT NULL AND person_id IS NULL),
 'public.converts.backfill_wrong_scope', (SELECT count(*)::bigint FROM public.converts c WHERE c.person_id IS NOT NULL AND NOT EXISTS (SELECT FROM public.ministry_people p WHERE p.id=c.person_id AND p.congregation_id=c.congregation_id)),
 'public.ministry_students.person_wrong_scope', (SELECT count(*)::bigint FROM public.ministry_students s WHERE s.person_id IS NOT NULL AND NOT EXISTS (SELECT FROM public.ministry_people p WHERE p.id=s.person_id AND p.congregation_id=s.congregation_id)),
 'public.ministry_people.count_matches_scoped_converts', ((SELECT count(*) FROM public.ministry_people)=(SELECT count(*) FROM public.converts WHERE congregation_id IS NOT NULL))
)::text;
ROLLBACK;
"""


def catalog_as_contract(observed):
    contract = {key: {} for key in CONTRACT_KEYS}
    for item in observed.get("columns", []):
        identity = f"{item['schema']}.{item['table']}.{item['column']}"
        contract["columns"][identity] = {key: item[key] for key in ("type", "nullable", "default_fingerprint", "generated")}
    for item in observed.get("constraints", []):
        contract["constraints"][f"{item['schema']}.{item['table']}.{item['name']}"] = item["definition_fingerprint"]
    for item in observed.get("indexes", []):
        contract["indexes"][f"{item['schema']}.{item['name']}"] = item["definition_fingerprint"]
    for item in observed.get("policies", []):
        target = f"{item['schema']}.{item['table']}"
        contract["policies"].setdefault(target, {})[item['name']] = {
            key: item[key] for key in ("command", "roles", "qual_fingerprint", "check_fingerprint")}
    for item in observed.get("functions", []):
        identity = f"{item['schema']}.{item['name']}({item['identity']})"
        contract["functions"][identity] = {"definition_fingerprint": item["definition_fingerprint"],
                                            "security_definer": item["security_definer"]}
    for item in observed.get("rls", []):
        contract["rls"][f"{item['schema']}.{item['table']}"] = {"enabled": item["enabled"], "forced": item["forced"]}
    for item in observed.get("table_grants", []):
        target = f"{item['schema']}.{item['table']}"
        contract["table_grants"].setdefault(target, {}).setdefault(item['grantee'], []).append(item["privilege"])
    for item in observed.get("function_grants", []):
        target = f"{item['routine_schema']}.{item['routine_name']}({item['identity_arguments']})"
        contract["function_grants"].setdefault(target, {}).setdefault(item['grantee'], []).append(item["privilege"])
    for item in observed.get("data_invariants", {}).items():
        contract["data_invariants"][item[0]] = item[1]
    for targets in (contract["table_grants"], contract["function_grants"]):
        for roles in targets.values():
            for privileges in roles.values():
                privileges.sort()
    return contract


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project-ref", required=True)
    parser.add_argument("--endpoint", required=True, help="must be db.<project-ref>.supabase.co")
    parser.add_argument("--service", required=True, help="managed libpq service name (credentials remain in service file)")
    parser.add_argument("--contracts", required=True, help="local semantic fingerprint contract JSON")
    parser.add_argument("--output", required=True)
    args = parser.parse_args()
    endpoint = validate_project_endpoint(args.project_ref, args.endpoint)
    try:
        contract_document = json.loads(Path(args.contracts).read_text(encoding="utf-8"))
        expected_versions = contract_document["versions"]
        validate_contract_document(contract_document)
    except (OSError, json.JSONDecodeError, KeyError, TypeError, ValueError) as exc:
        parser.error("could not read a valid local semantic contract file")
    addresses = resolve_endpoint_addresses(endpoint)
    observed = None
    for address in addresses:
        conninfo = build_endpoint_conninfo(args.project_ref, endpoint, address, args.service)
        proc = subprocess.run(["psql", conninfo, "-X", "-q", "--no-password",
                               "-v", "ON_ERROR_STOP=1", "-At", "-c", CATALOG_SQL],
                              env=sanitized_libpq_environment(), text=True,
                              capture_output=True, timeout=90)
        if proc.returncode:
            print("read-only catalog inventory failed", file=sys.stderr)
            raise SystemExit(proc.returncode)
        try:
            observed = json.loads(proc.stdout)
        except json.JSONDecodeError:
            print("catalog response was not valid JSON", file=sys.stderr)
            raise SystemExit(2)
        break
    if observed is None:
        raise SystemExit("no endpoint address could be inventoried")
    catalog_raw = json.loads(json.dumps(observed))
    if observed.get("capabilities", {}).get("ministry_people"):
        proc = subprocess.run(["psql", build_endpoint_conninfo(args.project_ref, endpoint, address, args.service),
                               "-X", "-q", "--no-password", "-v", "ON_ERROR_STOP=1", "-At",
                               "-c", BACKFILL_CATALOG_SQL], env=sanitized_libpq_environment(),
                              text=True, capture_output=True, timeout=90)
        if proc.returncode:
            print("read-only backfill invariant inventory failed", file=sys.stderr)
            raise SystemExit(proc.returncode)
        try:
            catalog_raw["data_invariants"].update(json.loads(proc.stdout))
        except (json.JSONDecodeError, TypeError):
            print("backfill invariant response was not valid JSON", file=sys.stderr)
            raise SystemExit(2)
    observed_contract = catalog_as_contract(catalog_raw)
    ledger_versions = {item["version"] for item in observed.get("ledger", [])}
    from migration_semantic_manifest import classify_manifest_inventory
    classifications = classify_manifest_inventory(contract_document, observed_contract, ledger_versions)
    report = {"project_ref": args.project_ref, "endpoint": endpoint,
              "mode": "READ ONLY", "scope_rpc_called": False,
              "migration_classification": classifications}
    output = Path(args.output).resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote read-only catalog inventory to {output}")


if __name__ == "__main__":
    main()
