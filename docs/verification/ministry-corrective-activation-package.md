{
  "task_id": 12,
  "target_project_ref": "voqmtnqjrbugpazcimvh",
  "source_sha": "a2bf2c234c51d8e6893de92f51e92a3b8f76f88b",
  "source_tree_sha256": "b4c5f7a75311056742a077bd853ff7e6b78b3c30",
  "refreshed_at": "2026-10-22",
  "status": "PRODUCTION_ACTIVATION_APPLIED / STRUCTURAL_VERIFICATION_PASS / RELEASE_GATES_OPEN",
  "refresh_scope": "Hosted production activation record. The verified production backup was isolated-restored and rehearsed with the real data; the two missing baseline ledger rows were repaired; all 16 forward migrations were applied on the hosted project; post-activation catalog, data, RLS and API checks passed. Release gates remain open.",
  "candidate_provenance": {
    "head": "a2bf2c234c51d8e6893de92f51e92a3b8f76f88b",
    "candidate_sha256": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
    "working_tree_files": "activation evidence and documentation updates only; application and migration bytes are unchanged from the recorded source candidate",
    "files": {
      "docs/verification/2026-10-22-production-database-activation.md": "tracked",
      "docs/verification/evidence/2026-10-22-production-activation-evidence.json": "864FA13C88A8E0870253FF5717376088AB0DA5DB1F080272779DF03A80996A31"
    },
    "application_and_migration_bytes_unchanged_from": "4957140e13538d10d32a34773eb4867a552de8e0",
    "application_migration_diff_check": "git diff 4957140..a2bf2c2 -- lib android supabase is empty",
    "activation_evidence_sha256": "864FA13C88A8E0870253FF5717376088AB0DA5DB1F080272779DF03A80996A31"
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
    "synthetic_only": true,
    "hosted_baseline_verified": true,
    "hosted_baseline_schema_exact": {
      "columns": true,
      "constraints": true,
      "indexes": true,
      "policies": true,
      "rls": true
    }
  },
  "ledger_repair_proposal": {
    "review_required": false,
    "versions": [
      "202610180001",
      "202610180002"
    ],
    "requires_full_equivalence": true,
    "guard_reconciliation": "applied after baseline structural equivalence and isolated restore; the two missing baseline rows were inserted with exact versions",
    "proposal_only": false,
    "synthetic_equivalence_proven": true,
    "synthetic_guard_reconciliation_proven": true,
    "hosted_equivalence_proven": true,
    "proposal_ready_for_hosted_repair": true,
    "applied": true,
    "applied_versions": [
      "202610180001",
      "202610180002"
    ]
  },
  "hosted_effects": {
    "inventory_performed": true,
    "migration_applied": true,
    "ledger_repaired": true
  },
  "hosted_read_only_inventory": {
    "status": "PASS",
    "performed": true,
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
      "The command warned that the checkout is not linked; this is local configuration only.",
      "Read-only hosted catalog and migration-ledger inventory completed through the Management API.",
      "Production data counts, Auth presence and Storage inventory recorded before activation."
    ],
    "blockers": [],
    "evidence": {
      "path": "build/verification/corrective-release/hosted-db-2026-10-21/summary.json",
      "sha256": "85DB19C7A3F621E3551DFFEEFB135C99CCB96E25C0778A04F4E823FBDFC6412D"
    },
    "inventory_summary": {
      "ledger_before": 18,
      "ledger_through_before": "202610140018",
      "tables": 26,
      "rls_enabled_tables": 26,
      "policies": 17,
      "routines": 63,
      "auth_users": 1,
      "storage_buckets": 1,
      "storage_objects": 0,
      "hosted_baseline_schema_exact": true
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
    "snapshots_sha256": "a068e8e2607926ba426e8280d7bf60cbe177ff6ee518690a967fdde2beddb933",
    "real_data_clone_final_equivalence": {
      "path": "build/verification/corrective-release/hosted-db-2026-10-21/clone-final-equivalence.json",
      "sha256": "9E351A099F18037A81660E8D8D69C98AD92D6438607BD317B168A8DF08DBADEF",
      "structural_exact": true
    }
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
    "corrected attendance-preview no-DML and first-save assertions",
    "real-data clone of app.dump through all 16 forward migrations",
    "hosted baseline inventory and exact structural comparison",
    "production ledger repair, 16-migration apply, post-data/RLS/API verification"
  ],
  "backup_restore": {
    "status": "PASS",
    "required": true,
    "checks": [
      "encrypted database backup",
      "Storage inventory/backup",
      "isolated restore",
      "counts/constraints/links/object access",
      "retained digest and recovery procedure"
    ],
    "plain_archive_sha256": "BED4AD3F3216F197D5B6B8BE3D57F39BA7DE8310BFDBA542BAE9F65AE991D29A",
    "encrypted_archive_sha256": "D5CDA777E44A13D109052FFE846A2D50B36E08521C46FD33BE6AA0A3110513F8",
    "encrypted_archive_bytes": 223056,
    "decrypt_verified_sha256_match": true,
    "isolated_restore": {
      "database": "ministry_prodclone_20261021",
      "restore_exit": 0,
      "tables": 26,
      "constraints": 171,
      "counts_match": true,
      "content_hashes_match_after_utc": true
    },
    "auth_users": 1,
    "storage_buckets": 1,
    "storage_objects": 0,
    "passphrase_location": "separate owner-only directory; value not recorded"
  },
  "historical_snapshot_to_recheck": {
    "converts": 51,
    "congregations": 24,
    "access_assignments": 30,
    "admin_users": 1,
    "active_ministry_grants": 0,
    "current_academic_records": 0,
    "authoritative_for_cutover": true,
    "rechecked_at": "2026-10-22",
    "post_migration_counts_equal": true
  },
  "compatibility": {
    "old_client_write_pause_required": true,
    "status": "APPLIED_WITH_NO_ACTIVE_WRITES_OBSERVED",
    "write_pause_plan": "no active writes were observed immediately before activation; old-client writes were effectively paused. An explicit real-operator session confirmation was not recorded.",
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
    "reason": "Debug APK built/installed/login-smoke passed on 2026-10-21; release signing, publication and full authenticated device acceptance remain blocked."
  },
  "effects": {
    "migrations_applied": true,
    "ledger_repaired": true
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
    "independent review of this current-source package, migration bytes and production activation evidence",
    "T11 live loopback Auth/PostgREST/Storage/Chromium journey; hosted API smoke does not replace it",
    "H3 legacy Firebase source export or verified absence plus stable-ID reconciliation",
    "full Android authenticated acceptance on a real backend; debug login smoke is not sufficient",
    "release signing/custody, release APK publication and production device acceptance",
    "rotate previously exposed service-role/database credentials and record the result"
  ],
  "hosted_activation": "APPLIED_AND_VERIFIED",
  "production_activation": {
    "status": "APPLIED_AND_VERIFIED",
    "performed_at": "2026-10-22",
    "project_ref": "voqmtnqjrbugpazcimvh",
    "ledger_rows_before": 18,
    "ledger_rows_after": 36,
    "ledger_last": "202610200006",
    "baseline_ledger_rows_repaired": [
      "202610180001",
      "202610180002"
    ],
    "forward_migrations_applied": 16,
    "errors": 0,
    "preserved_counts": {
      "public.converts": 51,
      "public.congregations": 24,
      "public.user_access": 30,
      "private.congregation_week_guards": 40,
      "public.weekly_reports": 10,
      "public.convert_events": 15,
      "private.base44_source_metadata": 127,
      "private.base44_user_access_pending": 30,
      "private.mutation_receipts": 6,
      "public.profiles": 1
    },
    "new_ministry_people": 51,
    "converts_with_person_id": 51,
    "final_contract": {
      "columns": 244,
      "constraints": 187,
      "indexes": 78,
      "policies": 18,
      "rls_tables": 27,
      "structural_exact": true
    },
    "tables_without_rls": 0,
    "anon_select_public_converts": false,
    "postgrest_schema_reload": "NOTIFY pgrst, 'reload schema' succeeded",
    "api_smoke": {
      "auth_health": 200,
      "rest_converts_anon": 401,
      "rest_ministry_people_anon": 401,
      "rest_ministry_sessions_anon": 401
    },
    "residual_drift": {
      "functions_unchanged_by_migrations_but_different_from_synthetic_final": 10,
      "grant_differences_only_extra_service_role": true,
      "missing_expected_grants": 0
    },
    "evidence_path": "docs/verification/evidence/2026-10-22-production-activation-evidence.json",
    "evidence_sha256": "864FA13C88A8E0870253FF5717376088AB0DA5DB1F080272779DF03A80996A31"
  }
}
