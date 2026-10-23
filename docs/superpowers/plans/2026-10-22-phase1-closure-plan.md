# Phase 1 Form/UX Closure Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close the Phase 1 form and ministry-navigation release with accurate evidence: a correctly configured APK, a read-only device navigation audit, a diagnosis of the Discipulado scope failure, and a verification document that claims only what was observed.

**Architecture:** No product behavior changes in this plan. Tasks 1-3 produce or reconcile evidence from the already-built `757d0c9` code commit and the configured debug APK; Task 4 records the results and the remaining gates. Any discovered product defect becomes a follow-up plan task, not an unreviewed edit inside a verification task.

**Tech Stack:** Flutter 3.47.7/Dart 3.13.5, Android debug build, `adb`/`uiautomator`, Supabase public client configuration, Markdown evidence.

**Spec:** `docs/superpowers/specs/2026-10-18-ministry-production-completion-design.md` for ministry entries, plus the approved Phase 1 requirements recorded in `docs/verification/2026-10-22-phase1-form-ux.md`.

## Global Constraints

- Branch: `codex/ministry-production-completion`. Local commits are allowed; never push the app branch.
- Do not change product code, tests, migrations, or production data in this plan.
- Device work is read-only: no create, edit, finalize, cancel, promotion, enrollment, or Storage write. Navigation taps and back presses only.
- Never print, commit, or embed `SUPABASE_ANON_KEY`, `SUPABASE_URL` values beyond the public host, service-role keys, database passwords, or `service.json`.
- The configured APK under test is `build/app/outputs/flutter-apk/app-debug.apk`, 136,304,948 bytes, SHA-256 `d07ab76cb83ede4bd6185c6ac37147719872b2ad59f70e73d2505fcfc1fc0735`.
- Device baseline: Xiaomi `2109119DG` (`lisa_eea`), Android 14/API 34, arm64-v8a, package `br.org.ieadpe.ieadpe_converts`, launcher `.MainActivity`.
- The app currently has a persisted Supabase session, so it renders the authenticated shell instead of `LoginPage`. Do not clear app data or sign out.
- Every device claim needs a UI dump, a log excerpt, or a command result. No claim from a screenshot or from memory.
- Release signing, release publication, production acceptance, phone backfill, and the Phase 2 `new_convert` filter remain out of scope.

## Review Focus

- A navigation tap landing on a write action: confirm the node's `content-desc`/bounds before every tap; if the target label is not the expected navigation label, stop and record `BLOCKED`.
- Session expiry or scope loss during the audit: record the visible state and the log line instead of retrying a write.
- A stale error from cached state: cold-start before the Discipulado diagnosis and distinguish a cached banner from a fresh failure.
- Evidence leaking a token: scan every captured text/log file for `sb_publishable_`, `sb_secret_`, `Bearer `, and `service_role` before saving.
- Overclaiming: smoke and read-only navigation never become "production acceptance"; each evidence line states its scope.

---

### Task 1: Reconcile the configured-APK evidence

**Files:**
- Modify: `docs/verification/2026-10-22-phase1-form-ux.md`
- Read: `build/verification/phase1-config-apk-2026-10-22/evidence.json`
- Read: `build/verification/phase1-config-apk-2026-10-22/ui-text.txt`

**Interfaces:**
- Consumes: the configured-APK probe result already recorded in the local evidence directory.
- Produces: a corrected "Debug APK" and "Device" section that Tasks 2-4 extend; exact hash/size/device strings for later tasks.

- [ ] **Step 1: Verify the evidence source**

Run: `Get-FileHash build\app\outputs\flutter-apk\app-debug.apk -Algorithm SHA256` and compare with the hash in `evidence.json`.
Expected: `D07AB76CB83EDE4BD6185C6AC37147719872B2AD59F70E73D2505FCFC1FC0735` and size `136304948`.
If either differs, stop and record `BLOCKED` in the ledger; do not rewrite the document.

- [ ] **Step 2: Replace the stale APK section**

In `docs/verification/2026-10-22-phase1-form-ux.md`, replace the old no-config hash (`941070…`) and the "no attached device" claim with:
- the configured APK path, target `android-arm64`, size, SHA-256, and build timestamp `2026-10-22T23:53:30-03:00`;
- `adb install -r` result `Success`;
- launcher `br.org.ieadpe.ieadpe_converts/.MainActivity` started `COLD`;
- `supabase.supabase_flutter: INFO: ***** Supabase init completed *****`;
- the visible shell labels from `ui-text.txt`;
- an explicit statement that a persisted session exists, so the login screen was not rendered and login was not exercised.

- [ ] **Step 3: Remove the stale device blocker**

Delete the "Device pass blocked: adb reported no attached device" bullet. Keep the Discipulado, write-journey, backfill, Phase 2, credential-rotation, and restore-evidence blockers unchanged.

- [ ] **Step 4: Scan for secrets and overclaims**

Run a case-insensitive scan of the edited document for `sb_publishable_`, `sb_secret_`, `Bearer `, `service_role`, and the literal `SUPABASE_ANON_KEY`.
Expected: zero matches. Confirm every new sentence is limited to install/launch/init/shell evidence.

- [ ] **Step 5: Commit**

```bash
git add docs/verification/2026-10-22-phase1-form-ux.md
git commit -m "docs: correct phase 1 configured APK evidence"
```

---

### Task 2: Read-only device navigation audit

**Files:**
- Create: `build/verification/phase1-device-2026-10-23/navigation.json`
- Create: `build/verification/phase1-device-2026-10-23/ui/` (one XML/text dump per screen)
- Read: `lib/widgets/app_shell.dart` for the expected labels and route names

**Interfaces:**
- Consumes: the installed configured APK from Task 1 and the persisted session.
- Produces: `navigation.json` with one object per check: `{screen, expected, observed, bounds, verdict}`; Task 4 consumes it.

- [ ] **Step 1: Confirm the device and app state**

Run: `adb devices -l`, `adb shell pidof br.org.ieadpe.ieadpe_converts`, `adb shell dumpsys activity activities | Select-String mResumedActivity`.
Expected: the Xiaomi device is `device`; the app PID exists; the resumed activity is `br.org.ieadpe.ieadpe_converts/.MainActivity`.
If the device is absent, stop and record `BLOCKED`.

- [ ] **Step 2: Cold-start and capture the baseline**

Run: `adb shell am force-stop br.org.ieadpe.ieadpe_converts`, then `adb shell am start -W -n br.org.ieadpe.ieadpe_converts/.MainActivity`.
Dump the UI with `adb shell uiautomator dump /sdcard/window.xml`, pull it to `build/verification/phase1-device-2026-10-23/ui/00-baseline.xml`, and extract `text`/`content-desc`/`bounds`.
Expected baseline labels include `Início`, `Convertidos`, `Discipulado`, `Menu`, `Abrir menu`, and `Cadastrar Novo Convertido`.

- [ ] **Step 3: Audit Início and Convertidos**

Tap only nodes whose `content-desc` is exactly `Início` or `Convertidos` (use the recorded bounds). After each tap, dump the UI, record the screen's heading and list/empty state, and press `adb shell input keyevent 4` to return.
Expected: the heading matches the tapped destination; the screen renders without `Serviço indisponível`, `Não foi possível`, or a red error banner. Record `PASS` or the exact visible error.

- [ ] **Step 4: Audit Discipulado and Alunos**

Tap `Discipulado`, then locate the `Alunos` entry and tap it. Dump each screen.
Expected: `Discipulado` renders its section; `Alunos` renders its list or a justified empty state; neither shows `Serviço indisponível`.
Do not tap `Cadastrar`, `Cadastrar aluno`, or any form control in this task.

- [ ] **Step 5: Verify the restored student-registration entry and hidden handoff**

On the `Alunos` screen, confirm a node with `content-desc` containing `Cadastrar aluno` exists and record its bounds. Do not tap it.
Open the navigation drawer/menu and record every visible entry. Expected: no handoff/new-convert entry appears in the sidebar. Do not open the hidden handoff route.
Record the handoff check as `PASS` only if the drawer dump shows its absence; otherwise `FAIL` with the observed label.

- [ ] **Step 6: Scan and save the evidence**

Scan all captured XML/text for `sb_publishable_`, `sb_secret_`, `Bearer `, and `service_role`; redact matches before saving.
Write `navigation.json` with the device serial, package, APK hash, timestamp, and one verdict per check. Include a top-level `mutations: "none"` field.

- [ ] **Step 7: Commit the findings summary only**

Do not commit the git-ignored evidence directory. If Task 4 needs a tracked summary, it writes it there; this task ends with a clean working tree and a reported verdict table.

---

### Task 3: Diagnose the Discipulado authorized-congregation failure

**Files:**
- Create: `build/verification/phase1-device-2026-10-23/discipulado.json`
- Read: `lib/features/ministry/` scope-loading code and the current screen logs

**Interfaces:**
- Consumes: the persisted session and the installed APK.
- Produces: `discipulado.json` with `state` (`PASS`, `FAIL`, or `BLOCKED`), `visible_text`, `log_excerpt`, `rpc_or_http_evidence`, and `root_cause_hypothesis`; Task 4 consumes it.

- [ ] **Step 1: Capture a clean foreground log**

Run `adb logcat -c`, cold-start the app, open `Discipulado`, wait 8 seconds, then capture `adb logcat -d --pid=$(adb shell pidof br.org.ieadpe.ieadpe_converts)`.
Expected: either the screen renders the authorized congregations, or the failure text plus a Supabase/PostgREST error appears.

- [ ] **Step 2: Record the visible state**

Dump the UI and extract every `text`/`content-desc`. Record whether `Não foi possível carregar as congregações autorizadas.` or `Nenhuma congregação autorizada está disponível para esta sessão.` is present.
If neither is present and the congregation picker/list is usable, record `PASS` and skip to Step 5.

- [ ] **Step 3: Correlate with the scoped read**

Identify the exact repository call that loads congregations from the log (function name or HTTP path). Do not print tokens; record only the path, status, and a redacted error code/message.
If the log shows no request, record `no_request_made`; if it shows a 4xx/5xx, record the status and the redacted response code.

- [ ] **Step 4: Classify the cause**

Choose one: `session_scope_empty`, `rpc_error`, `client_filter`, `stale_cache`, or `unknown`. Justify it with the log/UI evidence. Do not change code; if a fix is needed, write the smallest proposed change and mark it `follow-up required`.

- [ ] **Step 5: Save and scan the evidence**

Write `discipulado.json` with the fields above and `mutations: "none"`. Scan it for secrets before saving. Do not commit it.

---

### Task 4: Record the closure results and run the final review

**Files:**
- Modify: `docs/verification/2026-10-22-phase1-form-ux.md`
- Modify: `docs/verification/ministry-corrective-local-report.md` (only if it repeats the stale device/no-device claim)
- Read: `build/verification/phase1-device-2026-10-23/navigation.json`
- Read: `build/verification/phase1-device-2026-10-23/discipulado.json`

**Interfaces:**
- Consumes: Task 1 corrected evidence, Task 2 navigation verdicts, Task 3 diagnosis.
- Produces: a final Phase 1 verification section that a release reviewer can audit without rerunning the device.

- [ ] **Step 1: Add the read-only device audit table**

Append a table with one row per check from `navigation.json`: Início, Convertidos, Discipulado, Alunos, `Cadastrar aluno` entry, hidden handoff. Use the exact observed labels and verdicts; mark anything not reached as `BLOCKED`, not `PASS`.

- [ ] **Step 2: Add the Discipulado diagnosis**

Record the `state`, the exact visible text, the redacted log/HTTP evidence, and the classification from `discipulado.json`. If `follow-up required`, add a bullet under blockers naming the proposed change; do not implement it.

- [ ] **Step 3: Reconcile the scope statement**

State exactly what was and was not exercised: authenticated shell and read-only navigation yes; login, OAuth, create/edit/finalize/cancel, Storage, release signing, and production acceptance no. Remove any sentence that implies full Android acceptance.

- [ ] **Step 4: Verify the document**

Confirm the APK hash/size matches Task 1, every table verdict has an evidence file, no secret markers exist, and `git status` shows only the intended docs.
Expected: zero secret matches; no new claim without an evidence path.

- [ ] **Step 5: Commit**

```bash
git add docs/verification/2026-10-22-phase1-form-ux.md docs/verification/ministry-corrective-local-report.md
git commit -m "docs: record phase 1 read-only device closure"
```

- [ ] **Step 6: Final whole-branch review**

Run the final review over the Phase 1 commit range (`578b6f4..HEAD`) with `superpowers:requesting-code-review`. Fix only review findings that are load-bearing for the evidence claims; park the rest with a ledger ruling.

---

## Self-Review

- **Spec coverage:** The approved Phase 1 requirements are already implemented at `757d0c9`; this plan covers the missing evidence for the configured build, navigation, the Discipulado failure, and the release statement. Linux, Phase 2, backfill, signing, and publication stay out of scope.
- **Step scan:** Each task has one deliverable and checkable commands. Task 2 avoids write controls; Task 3 diagnoses without editing.
- **Type consistency:** `navigation.json` and `discipulado.json` field names are fixed in their Interfaces blocks and reused in Task 4.
- **Review Focus:** Taps on write controls, session expiry, stale errors, secret leakage, and overclaiming each have an explicit check.
- **Proportion:** Four tasks for evidence reconciliation, device audit, diagnosis, and the final record; no product code is transcribed.
