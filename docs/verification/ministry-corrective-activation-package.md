{
  "task_id": 12,
  "target_project_ref": "voqmtnqjrbugpazcimvh",
  "source_sha": "4957140e13538d10d32a34773eb4867a552de8e0",
  "source_tree_sha256": "b4c5f7a75311056742a077bd853ff7e6b78b3c30",
  "refreshed_at": "2026-10-21",
  "status": "LOCAL_REHEARSAL_PASS / REVIEW_PENDING / HOSTED_INVENTORY_BLOCKED",
  "refresh_scope": "Current-source read-only package refresh. The local 16-migration chain was rehearsed against the current bytes on an owned disposable loopback PostgreSQL; hosted catalog inventory was not performed.",
  "candidate_provenance": {
    "head": "4957140e13538d10d32a34773eb4867a552de8e0",
    "candidate_sha256": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
    "working_tree_files": "none; clean checkout. source_sha and source_tree_sha256 bind the candidate.",
    "files": {}
  },
  "migration_sequence": [
    {
      "version": "202610180003",
      "filename": "202610180003_base44_unified_access.sql",
      "sha256": "fb163a031354519b8aab9dde1c1092281a6b8aa4168e2b1b324854afe90f7849"
    },
    {
      "version": "202610190001",
      "filename": "202610190001_ministry_people_identity.sql",
      "sha256": "cecf58af75fa5f91e9953c3f065335ea89bb312887bf0ef3022c3b18ebdf06c8"
    },
    {
      "version": "202610190002",
      "filename": "202610190002_ministry_student_registration.sql",
      "sha256": "62f2b1912de4b9d9dd4e1accdf3ed763c2553f1dbc2cb8c6790f6bbb2f80b55b"
    },
    {
      "version": "202610190003",
      "filename": "202610190003_ministry_team_access.sql",
      "sha256": "dd0a626622438a9a1c06514afea3e281d97aad9643a653385c143e34baae2c72"
    },
    {
      "version": "202610190004",
      "filename": "202610190004_ministry_student_academic_link.sql",
      "sha256": "041e577e1beaea2803ee948c1b1b055091db47d654d4e95391feb3830ff36178"
    },
    {
      "version": "202610190005",
      "filename": "202610190005_ministry_access_candidates.sql",
      "sha256": "96d02033354f4400380225299f41c611a998188b5334c44e624ad1a73342c7e1"
    },
    {
      "version": "202610190006",
      "filename": "202610190006_ministry_class_management_guards.sql",
      "sha256": "080b56115b70948c989f9ce730cf5bec765a23ab4cf1cee710d0c1f91f8ddb02"
    },
    {
      "version": "202610190007",
      "filename": "202610190007_ministry_class_receipt_replay.sql",
      "sha256": "c684131258f5057c3ea2fd7480fe8e1f89bf04357f0dbe6af280e7ed8aad92e1"
    },
    {
      "version": "202610190008",
      "filename": "202610190008_ministry_derived_follow_up.sql",
      "sha256": "66e43e3ba432f1f629a269e410d81d4b939fea584e45e34eed8aa5324ddb3e1d"
    },
    {
      "version": "202610190009",
      "filename": "202610190009_ministry_session_management.sql",
      "sha256": "49fdf99aa21c4df4acc38c852c1423c8569474bd8364c29cd6a121318cf2d1f4"
    },
    {
      "version": "202610200001",
      "filename": "202610200001_import_revision_compatibility.sql",
      "sha256": "2721b6b7b4f158389e0628242e12b9c1e406bc679c94de299263dcf40887d1b9"
    },
    {
      "version": "202610200002",
      "filename": "202610200002_canonical_handoff_reads.sql",
      "sha256": "5f722926d7301360973220395dc37e4159ad606903493598b77a53a273eb97d3"
    },
    {
      "version": "202610200003",
      "filename": "202610200003_attendance_integrity.sql",
      "sha256": "fb3da95f694a9b1e5351371531fa4b9d1d8c63ecf699c2e8be58bf80bd80f4f1"
    },
    {
      "version": "202610200004",
      "filename": "202610200004_student_enrollment_history.sql",
      "sha256": "aa5803a824f8aaba8f92d8b3974d387854537507c7b20999c973faeb86da9c95"
    },
    {
      "version": "202610200005",
      "filename": "202610200005_campaign_scope_compatibility.sql",
      "sha256": "b4cbc6ae43b1d10df088dd23f61bcc0073a0db2a854cb3d158ee1f26341eec0b"
    },
    {
      "version": "202610200006",
      "filename": "202610200006_attendance_roster_preview.sql",
      "sha256": "825020ce2098fc70cab3903a85bec3a1149df78262030ff93c350952d5331b91"
    }
  ],
  "resume_drift_rehearsal": {
    "partial_prefix_count": 2,
    "pending_versions": [
      "202610190002",
      "202610190003",
      "202610190004",
      "202610190005",
      "202610190006",
      "202610190007",
      "202610190008",
      "202610190009",
      "202610200001",
      "202610200002",
      "202610200003",
      "202610200004",
      "202610200005",
      "202610200006"
    ],
    "checksum_drift_stopped": true,
    "ledger_repair_performed": false,
    "database_partial_resume_verified": true,
    "database_catalog_drift_stopped_before": "202610190002",
    "synthetic_drift_rolled_back": true
  },
  "baseline": {
    "last_schema_migration": "202610180002",
    "ledger_through": "202610140018",
    "synthetic_only": true
  },
  "ledger_repair_proposal": {
    "review_required": true,
    "versions": [
      "202610180001",
      "202610180002"
    ],
    "requires_full_equivalence": true,
    "guard_reconciliation": "independent proof required before any future repair",
    "proposal_only": true,
    "synthetic_equivalence_proven": true,
    "synthetic_guard_reconciliation_proven": true,
    "hosted_equivalence_proven": false,
    "proposal_ready_for_hosted_repair": false
  },
  "hosted_effects": {
    "inventory_performed": false,
    "migration_applied": false,
    "ledger_repaired": false
  },
  "hosted_read_only_inventory": {
    "status": "BLOCKED",
    "performed": false,
    "project_metadata": {
      "ref": "voqmtnqjrbugpazcimvh",
      "name": "Discipulado IEADPE",
      "region": "us-west-2",
      "status": "ACTIVE_HEALTHY",
      "linked": false,
      "database": {
        "host": "db.voqmtnqjrbugpazcimvh.supabase.co",
        "version": "17.11.0.003",
        "postgres_engine": "17",
        "release_channel": "ga"
      }
    },
    "safe_surfaces_observed": [
      "supabase projects list: project identity, region, status, database host and PostgreSQL version",
      "The command warned that the checkout is not linked; this is local configuration only."
    ],
    "blockers": [
      "No managed libpq PGSERVICE or libpq service file is configured.",
      "The project is linked:false and the checkout has no .supabase directory.",
      "The authenticated CLI/PAT session is not a database password and was not used as one.",
      "No schema, migration-ledger, function, policy or grant fingerprint was refreshed."
    ],
    "evidence": {
      "path": "build/verification/corrective-release/T12/read-only-refresh/hosted-project-read.json",
      "sha256": "6d0191eb4d9431f341e812a30493cacfcaa17c058692948656fc4bf2115a3b5b"
    }
  },
  "local_rehearsal": {
    "status": "PASS",
    "exit_code": 0,
    "completed": true,
    "elapsed_seconds": 17.011,
    "harness": "scripts/test_database.py",
    "database": "owned disposable loopback PostgreSQL 127.0.0.1:54329; one database per run",
    "report_path": "build/verification/corrective-release/T12/read-only-refresh/refreshed-local-rehearsal.json",
    "report_sha256": "4c10a25d70f850dd2db0866732af9afc1060f528226efc1cd8b7afa2e81631a5",
    "evidence_path": "build/verification/corrective-release/T12/read-only-refresh/refreshed-local-rehearsal.log",
    "evidence_sha256": "bab91edc178fb9d316529281b2b91866c68b710a10fdaf22722300bf267ee3da",
    "baseline": "synthetic seed staged after 202610180001, before 202610180002",
    "ledger_through": "202610140018",
    "blind_base44_ddl_replay_failed_as_expected": "CREATE TABLE duplicate caught by assertion",
    "synthetic_equivalence_checks": "passed",
    "weekly_guard_reconciliation": "passed",
    "post_180002_baseline_assertions": "passed before the forward chain",
    "database_partial_resume": "passed after controlled stop at 202610190001; remaining exact chain applied",
    "database_catalog_drift": "detected on ministry_people and stopped before 202610190002; synthetic DDL rolled back",
    "ledger_repair_executed": false,
    "semantic_snapshot_count": 16,
    "hosted_effects": false
  },
  "semantic_manifest": {
    "path": "build/verification/corrective-release/T12/semantic-manifest.json",
    "sha256": "d8845392ab3c719c418448846ad2129a1e66298876200a8cef627b034055635a",
    "snapshots_path": "build/verification/corrective-release/T12/semantic-snapshots.json",
    "snapshots_sha256": "a068e8e2607926ba426e8280d7bf60cbe177ff6ee518690a967fdde2beddb933"
  },
  "checkpoint_count": {
    "total": 17,
    "baseline": "202610180002",
    "version_checkpoints": 16,
    "report_semantic_snapshot_count": 16,
    "explanation": "The report count excludes the separate baseline checkpoint."
  },
  "coverage": [
    "exact ordered local upgrade of the current 16 forward migrations",
    "prefix classification and partial resume from the 202610190001 prefix",
    "deliberate catalog-drift stop before 202610190002 and rollback of synthetic drift",
    "Base44 equivalence and weekly-guard reconciliation proposal only; no ledger repair",
    "corrected attendance-preview no-DML and first-save assertions"
  ],
  "backup_restore": {
    "status": "BLOCKED",
    "required": true,
    "checks": [
      "encrypted database backup",
      "Storage inventory/backup",
      "isolated restore",
      "counts/constraints/links/object access",
      "retained digest and recovery procedure"
    ]
  },
  "historical_snapshot_to_recheck": {
    "converts": 51,
    "congregations": 24,
    "access_assignments": 30,
    "admin_users": 1,
    "active_ministry_grants": 0,
    "current_academic_records": 0,
    "authoritative_for_cutover": false
  },
  "compatibility": {
    "old_client_write_pause_required": true,
    "status": "INCOMPLETE",
    "write_pause_plan": "pause incompatible old-client writes before envelope changes; confirm by real operator sessions",
    "monitoring": [
      "authorization denials",
      "RPC/schema errors",
      "row/link reconciliation",
      "backup/restore status",
      "provider quota/capacity alerts"
    ],
    "rollback_stop_conditions": [
      "unknown target or schema drift",
      "failed restore",
      "authorization regression",
      "count/link mismatch",
      "old-client writes not paused",
      "new security/integrity failure"
    ],
    "rollback_procedure": "stop target writes, retain sources, restore only to an isolated destination, reconcile counts/constraints/links/object access, and retry only after the cause is understood"
  },
  "legacy_firebase": {
    "status": "BLOCKED",
    "reason": "source export or verified absence unavailable"
  },
  "android_artifact": {
    "status": "BLOCKED",
    "reason": "Physical Android 14 target is connected over ADB, but no authorized APK, install or app-acceptance evidence exists."
  },
  "effects": {
    "migrations_applied": false,
    "ledger_repaired": false
  },
  "historical_evidence": {
    "superseded_source_sha": "f2fffca489fd36f55957bba49736cb35dd31d5a6",
    "superseded_package_copy": "build/verification/corrective-release/T12/read-only-refresh/historical-package-f2fffca.json",
    "superseded_package_sha256": "b4d047b38df1db8c8d82e89c26c16485026efdd262ef84d0898fe05b16587728",
    "archive": "docs/verification/handoff/2026-10-21-corrective-evidence.tar.gz",
    "archive_member_root": "build/verification/corrective-release/T12/continuation-006/",
    "approval_transfer": "none; all 16 current migration hashes differ from the prior package. The f2fffca package and continuation-006 rehearsal remain historical evidence only."
  },
  "next_gates": [
    "H1 encrypted database/Storage backup and isolated measured restore",
    "H3 legacy Firebase source export or verified absence plus stable-ID reconciliation",
    "managed libpq service and authorized read-only catalog/ledger/function/policy/grant inventory",
    "independent review of this current-source package and migration bytes",
    "approved write-pause/compatibility plan before any hosted mutation",
    "separate signed Android artifact and device acceptance gates"
  ],
  "hosted_activation": "UNAPPROVED"
}
