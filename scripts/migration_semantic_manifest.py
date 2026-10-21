"""Build semantic migration fingerprints from disposable catalog snapshots.

This module deliberately does not infer an expected hosted state. Its input is
the read-only catalog captured after each authoritative migration on a
disposable database seeded with the T12 synthetic baseline.
"""
import json
from pathlib import Path
import re
import copy

from inspect_hosted_contracts import CONTRACT_KEYS, catalog_as_contract
from inspect_hosted_contracts import classify_migration_version
from rehearse_hosted_upgrade import migration_sequence

BASELINE_VERSION = "202610180002"


def extract_migration_time_dml(source_text):
    """List unindented migration-time DML, including target aliases."""
    return [{"line": number, "statement": line.strip()}
            for number, line in enumerate(source_text.splitlines(), 1)
            if re.match(r"^(INSERT\s+INTO|UPDATE\s+\S+(?:\s+\w+)?\s+SET|DELETE\s+FROM)\b", line, re.I)]


def _canonical(value):
    return json.dumps(value, sort_keys=True, separators=(",", ":"))


def _contract(snapshot):
    if not isinstance(snapshot, dict) or not all(key in snapshot for key in CONTRACT_KEYS):
        raise ValueError("snapshot must include complete semantic categories")
    if any(not isinstance(snapshot[key], dict) for key in CONTRACT_KEYS):
        raise ValueError("snapshot categories must be maps")
    if not any(snapshot[key] for key in CONTRACT_KEYS):
        raise ValueError("empty semantic snapshot is forbidden")
    return snapshot


def _diff(before, after):
    effects = {}
    identities = set()
    for category in CONTRACT_KEYS:
        old, new = before[category], after[category]
        changes = {}
        for identity in sorted(set(old) | set(new)):
            if identity not in old:
                changes[identity] = {"kind": "added", "after": new[identity]}
            elif identity not in new:
                changes[identity] = {"kind": "removed", "before": old[identity]}
            elif _canonical(old[identity]) != _canonical(new[identity]):
                changes[identity] = {"kind": "altered", "before": old[identity], "after": new[identity]}
        if changes:
            effects[category] = changes
            identities.update((category, identity) for identity in changes)
    if not effects:
        raise ValueError("migration snapshot has no catalog or invariant effects")
    return effects, identities


def build_manifest(bundle):
    """Validate snapshots and produce exact ordered effects plus object lineage."""
    if not isinstance(bundle, dict) or not isinstance(bundle.get("baseline"), dict):
        raise ValueError("snapshot bundle requires baseline and versions")
    baseline = bundle["baseline"]
    if baseline.get("version") != BASELINE_VERSION:
        raise ValueError("snapshot bundle requires the 180002 baseline")
    before = _contract(baseline.get("contract"))
    baseline_invariants = baseline.get("data_invariants")
    if not isinstance(baseline_invariants, dict) or not baseline_invariants:
        raise ValueError("baseline data invariants are required")
    sequence = migration_sequence()
    snapshots = bundle.get("versions")
    if not isinstance(snapshots, list) or len(snapshots) != len(sequence):
        raise ValueError("snapshots must contain the exact ordered migration sequence")
    expected = {item["version"]: item for item in sequence}
    checkpoints = [(BASELINE_VERSION, before, baseline_invariants)]
    versions = []
    previous_invariants = baseline_invariants
    for item, source in zip(snapshots, sequence):
        if not isinstance(item, dict) or item.get("version") != source["version"]:
            raise ValueError("snapshots must contain the exact ordered migration sequence")
        if item.get("source_sha256") != source["sha256"]:
            raise ValueError("snapshot source checksum does not match authoritative migration")
        after = _contract(item.get("contract"))
        effects, touched = _diff(before, after)
        invariants = item.get("data_invariants")
        if not isinstance(invariants, dict) or not invariants:
            raise ValueError(f"data invariant snapshot missing at {source['version']}")
        invariant_effects = {key: {"before": previous_invariants.get(key), "after": value}
                             for key, value in invariants.items()
                             if previous_invariants.get(key) != value}
        checkpoints.append((source["version"], after, invariants))
        source_text = (Path(__file__).resolve().parents[1] / "supabase/migrations" /
                       source["filename"]).read_text(encoding="utf-8")
        migration_time_dml = extract_migration_time_dml(source_text)
        versions.append({"version": source["version"], "filename": source["filename"],
                         "source_sha256": source["sha256"], "contract": after,
                         "effects": effects, "invariant_effects": invariant_effects,
                         "invariants": invariants,
                         "transform_evidence": {"migration_source_sha256": source["sha256"],
                             "catalog_invariant_changes": invariant_effects,
                             "migration_time_dml_statements": migration_time_dml,
                             "row_transform_provenance": "migration-time top-level DML is listed with source lines; function-body DML defines future operations and is not an upgrade-time transform"}})
        before, previous_invariants = after, invariants
    if [item["version"] for item in versions] != list(expected):
        raise ValueError("snapshots must contain the exact ordered migration sequence")
    identities = {(category, identity) for _, contract, _ in checkpoints
                  for category in CONTRACT_KEYS for identity in contract[category]}
    lineage = []
    by_version = {version: [] for version, _, _ in checkpoints}
    for category, identity in sorted(identities):
        events, last, seen = [], None, False
        for version, contract, _ in checkpoints:
            present = identity in contract[category]
            value = contract[category].get(identity)
            if present and not seen:
                event = {"version": version, "kind": "introduced", "fingerprint": value}
                events.append(event); by_version[version].append({"category": category, "identity": identity, **event})
            elif not present and seen:
                event = {"version": version, "kind": "removed"}
                events.append(event); by_version[version].append({"category": category, "identity": identity, **event})
            elif present and seen and _canonical(last) != _canonical(value):
                event = {"version": version, "kind": "altered", "fingerprint": value}
                events.append(event); by_version[version].append({"category": category, "identity": identity, **event})
            if present:
                seen, last = True, value
            else:
                seen, last = False, None
        lineage.append({"category": category, "identity": identity, "events": events})
    for version in versions:
        version["lineage"] = by_version[version["version"]]
    return {"schema_version": 1, "baseline": {"version": BASELINE_VERSION,
                "contract": bundle["baseline"]["contract"], "data_invariants": baseline_invariants},
            "versions": versions, "lineage": lineage,
            "provenance": {"source": "disposable PostgreSQL catalog snapshots",
                "hosted_state_proven": False, "migration_count": len(sequence)}}


def build_manifest_from_snapshot_file(path):
    document = json.loads(Path(path).read_text(encoding="utf-8"))
    return build_manifest(document)


def classify_checkpoint(entry, observed_contract, ledger_recorded):
    """Classify against one exact migration-boundary catalog snapshot."""
    if not isinstance(entry, dict) or not isinstance(entry.get("contract"), dict):
        raise ValueError("manifest checkpoint requires a complete semantic contract")
    return classify_migration_version(ledger_recorded, entry["contract"], observed_contract)


def classify_manifest_inventory(manifest, observed_contract, ledger_versions):
    """Classify every release version against the lineage-resolved final state.

    Boundary snapshots remain available for forensic/version-specific review,
    while this current-state classifier uses the last effective checkpoint so
    intentionally superseded definitions are not required to remain live.
    Aggregate synthetic counts are evidence only; semantic missing/stale
    invariants must remain zero in the observed catalog.
    """
    sequence = migration_sequence()
    versions = manifest.get("versions") if isinstance(manifest, dict) else None
    if not isinstance(versions, list) or [item.get("version") for item in versions] != [
            item["version"] for item in sequence]:
        raise ValueError("manifest must contain the exact ordered migration sequence")
    if not isinstance(observed_contract, dict) or set(observed_contract) != set(CONTRACT_KEYS):
        raise ValueError("observed catalog must contain every semantic category")
    if any(not isinstance(observed_contract[key], dict) for key in CONTRACT_KEYS):
        raise ValueError("observed semantic categories must be maps")
    def invariant_matches(expected, observed):
        for key, value in expected.items():
            if key.endswith(".count_preserved"):
                continue  # synthetic before/after proof; unavailable from a current hosted catalog
            if not key.endswith((".missing", ".stale", ".backfill_unlinked",
                                 ".backfill_wrong_scope", ".person_wrong_scope",
                                 ".count_matches_scoped_converts")):
                continue
            actual = observed.get(key)
            if key.endswith(".count_matches_scoped_converts"):
                if value is not True or actual is not True:
                    return False
            elif value != 0 or actual != 0:
                return False
        return True

    def contract_matches(expected):
        return (all(_canonical(expected[key]) == _canonical(observed_contract[key])
                    for key in CONTRACT_KEYS if key != "data_invariants")
                and invariant_matches(expected["data_invariants"], observed_contract["data_invariants"]))

    baseline = manifest.get("baseline", {}).get("contract")
    if not isinstance(baseline, dict) or set(baseline) != set(CONTRACT_KEYS):
        raise ValueError("manifest baseline contract is incomplete")
    checkpoints = [baseline, *(item["contract"] for item in versions)]
    matched = next((index for index, checkpoint in enumerate(checkpoints)
                    if contract_matches(checkpoint)), None)
    release_versions = [item["version"] for item in sequence]
    recorded = set(ledger_versions) & set(release_versions)
    has_release_objects = any(
        identity in observed_contract[category]
        for entry in versions for category, changes in entry["effects"].items()
        if category != "data_invariants" for identity in changes)
    if matched is None and not recorded and not has_release_objects:
        return [{"version": version, "state": "absent"} for version in release_versions]
    if matched is not None:
        applied_count = matched
        expected_prefix = set(release_versions[:applied_count])
        ledger_gap = bool(recorded - expected_prefix)
        saw_unrecorded = False
        for version in release_versions:
            if version not in recorded:
                saw_unrecorded = True
            elif saw_unrecorded:
                ledger_gap = True
        if ledger_gap:
            return [{"version": version, "state": "partial/conflicting"} for version in release_versions]
        results = []
        for index, item in enumerate(sequence, 1):
            version = item["version"]
            if index <= applied_count:
                if version in recorded:
                    state = "recorded+present" if not ledger_gap else "partial/conflicting"
                else:
                    state = "unrecorded+fully-equivalent" if not ledger_gap else "partial/conflicting"
            elif version in recorded:
                state = "partial/conflicting"
            else:
                state = "absent"
            results.append({"version": version, "state": state})
        return results

    # A catalog that is neither absent nor an exact known checkpoint cannot
    # establish per-version ownership safely. Fail closed rather than allowing
    # matching subsets to mask invariant or unexpected-object drift.
    return [{"version": version, "state": "partial/conflicting"} for version in release_versions]
