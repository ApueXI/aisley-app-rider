# AISLEY Rider V2 independent test report

Date: 2026-11-12 (Asia/Manila)

## Scope and setup

- Read `docs/PROGRESS.md` first, then `AGENTS.md`, the orchestrator tester role and its discovery/contracts references, the Courier UI review skill/template, and the Dart analyzer skill. Reviewed `docs/stitch/v2/IMPLEMENTATION.md`, `REVIEW.md`, the Courier design guide, and the matching auth, dashboard, pickup, batch, delivery/proof/completion, chat, history, notifications, linehaul, and policy contracts.
- Project snapshot: branch `feature/courier-stitch-v2-implementation`, HEAD `1dc83bcc744df34da3c692c6af9120956487dac9`; tested the copied working-tree snapshot at `source/` in this run directory. The capture predates a separately approved decorative scan-icon removal; that change does not overlap the findings below.
- Flutter 3.47.2 / Dart 3.13.2. The SDK cache stamp required a narrow elevated read/check. No dependencies, SDKs, or product files were changed.
- The source copy excluded `.git`, build output, `.dart_tool` except its public package configuration, original `.env*` except `.env.example`, and signing/credential files. The original `.env` was never read or copied. Only inside the isolated copy, `.env` linked to public `.env.example` so the declared asset resolves.
- The `--no-test-assets` run was interrupted after appearance tests repeatedly reported missing `shaders/ink_sparkle.frag`; this is a harness/environment limitation. The recorded full run used assets. Manual Stitch screenshot capture flags stayed at their default false; no screenshots were generated.

## Checks

| Check | Command | Result |
| --- | --- | --- |
| Static analysis | `flutter analyze --no-pub` | Pass: `No issues found!` |
| Full test suite | `flutter test --no-pub --concurrency=2 --reporter=json` | Exit 1. JSON log records 1,346 `testDone` events: 1,308 success, 32 error, 6 failure (38 failing cases). Full output: [`full-tests.jsonl`](../../build/stitch-ui/independent-test/run-20261112-01/full-tests.jsonl). |
| Pickup retry reproduction | `flutter test --no-pub --reporter=expanded test/manual/scratch_pickup_retry_after_reopen_test.dart` | Failed as expected: pending attempt remained, but retry button `onPressed` was null after mounting a fresh detail screen. Synthetic-only reproduction; source file removed afterward. Details: [`TEST-004-repro.md`](../../build/stitch-ui/independent-test/run-20261112-01/TEST-004-repro.md). |

The earlier compact reporter output ended at an intermediate `+1192 -38` progress line; it was not the final pass count. The captured JSON stream is the complete count used above.

## Findings

### TEST-001 — P2: Registration footer action overflows at 2× text

Evidence: `test/features/auth/registration_v26_test.dart`, “registration cooldown remains readable,” 320 px / 2.0×, dark and light. The full run reports a 248 px right overflow in `lib/features/auth/presentation/components/registration_form.dart:261`, inside the fixed-width footer button's text-and-arrow `Row`.

Impact: the main OTP action label is clipped at the narrow, enlarged-text setting, and Flutter reports a layout error.

Acceptance: the two failing scenarios pass accessibility/layout checks; the complete action label and arrow meaning remain visible, the control remains at least 48 px tall, and standard-scale behavior stays intact.

### TEST-002 — P2: History results header overflows at 2× text

Evidence: four 320 px / 2.0× light/dark cases in `test/features/history/history_accessibility_test.dart` (“history error, stale rows and retry” and “history search, keyboard focus and bounded results”). `lib/features/history/presentation/components/history_list.dart:106` reports a 62 px right overflow in the header row that combines result count and “Read-only view.”

Impact: header content is clipped in narrow enlarged-text layouts, and the error/stale and search accessibility checks fail.

Acceptance: all four scenarios pass without a layout exception; the result count and read-only label remain readable and keyboard/accessibility behavior is preserved.

### TEST-003 — P3: Dashboard section header has a small overflow

Evidence: `test/features/navigation/courier_shell_test.dart`, 390 px / 1.0×, dark and light. `lib/features/dashboard/presentation/components/dashboard_aggregate.dart:182` reports a 4.9 px right overflow in the section title/timestamp/“View all” row.

Impact: a small portion of the header row is clipped at a standard phone width.

Acceptance: both shell scenarios pass without a layout exception; title, timestamp, and “View all” remain visible and the action remains tappable.

### TEST-004 — P2: Pending first-mile pickup retry becomes unreachable after reopening detail

Evidence: a temporary widget reproduction in the isolated copy set up an accepted first-mile task, received a synthetic timeout from `confirmFirstMilePickup`, then mounted a fresh `PickupTaskDetailScreen`. `hasPendingAttempt(task)` stayed true, but “Retry pickup confirmation” had `onPressed == null`. The screen-local candidate starts null on remount; `pickup_task_detail.dart` gates retry on a candidate, while `pickup_task_actions.dart` disables rescanning when a pending attempt exists. The controller retains the pending payload/idempotency key for `retryFirstMilePickup`. This conflicts with `docs/features/courier/pick-up-order/specs.md:197`, which requires retries to use the same key and identifier payload.

Impact: after leaving and reopening the detail within the same session, the Courier has neither an enabled retry nor a way to scan again to recover an uncertain server result.

Acceptance: after a synthetic uncertain response, pop and reopen the same task; enable retry of the retained payload/key, keep duplicate/new scan submission blocked during that pending attempt, and verify a successful replay clears the pending action without changing the identifier or key. The raw scan value must not be displayed or logged for this reproduction.

This reproduction was requested by the lead and run only in the isolated copy. Its temporary test source was removed; no project test/source file was modified. The issue has since been approved for a separate implementation task; this report does not claim the fix is present or retested.

## Remaining full-suite failures

These are test/assertion triage, not additional product findings or authorization to change code.

**Stale assertions following the new layouts/labels (18 cases):**

- `delivery_route_screen_test.dart`: one assertion requires the new “View delivery route” control to be a `TextButton`; it is now an `OutlinedButton`.
- `final_mile_batch_accessibility_test.dart`: eight cases search for inline `FilledButton('Accept parcel')`. The revised flow presents `OutlinedButton('Review parcel')` and opens separate parcel details before “Accept delivery.” These checks stop before testing the revised flow.
- `registration_wizard_test.dart`: one assertion searches for “This code expired”; the revised screen displays “Code expired.”
- `auth_v26_screen_test.dart`: seven cases expect two exact “Sign in” strings; the revised sign-in heading is “Sign in to your rider account,” leaving one action label.
- `failed_attempt_screen_test.dart`: one case tries to reveal “Report failed attempt” while a completion is pending. The revised review screen omits that action and shows review/refresh state.

**Unattributed failures outside the changed screen logic (12 cases):**

- Four `delivery_buyer_chat_test.dart` states find/tap “Message Buyer” but then observe `chat.activeTask?.taskId == null` instead of `final-task`. The test and chat controller are unchanged; the delivery task's chat callback is unchanged in the diff. This run did not isolate the navigation cause.
- Two `chat_image_pagination_test.dart` enlarged-text cases cannot find the expected older image attachment after loading an older page. The test and chat-thread implementation are unchanged by this UI diff.
- Six `direct_delivery_test.dart` controller tests observe repeated writes with the same idempotency key: four physical-state cases duplicate proof-key calls, the partial-failure case records three completion keys where it expects two, and the uncertain-photo case records two completion keys where it expects one. These tests exercise the unchanged delivery controller directly; this UI review did not attribute or fix them.

## Limits and handoff

- No device/installed APK, camera permission, live API, web-camera, upload persistence, or production server behavior was exercised. The run is headless Flutter analysis/widget/unit testing on an isolated source copy.
- Owner screenshot captures and Stitch references are recorded in the implementation matrix, but this independent run did not produce or compare fresh rendered screenshots. It does not certify pixel fidelity or visual acceptance for all 16 target families.
- No product source, tests, docs, dependencies, environment files, or signing files were edited by this tester. Temporary output is limited to this `build/stitch-ui/independent-test/run-20261112-01/` directory.
- Requested model/effort was GPT-6 Luna/max; effective runtime model metadata was unavailable and remains unverified.

## Task 016 — final attribution of the 12 initially unclassified failures

The complete [Task 016 attribution report](../../build/stitch-ui/independent-test/run-20261112-02/ATTRIBUTION.md) compares 37 targeted test cases on both the V2 working-tree snapshot and base HEAD: 25 pass and 12 error/fail on each snapshot. It adds no new product finding.

The final full-suite JSON count is 1,346 `testDone` events: 1,308 success, 32 error, and 6 failure (38 failing cases). The compact reporter’s `+1192 -38` line was an intermediate progress update, not the final count. The 38 cases are attributed as follows:

- **8 responsive layout failures, TEST-001–003:** two registration footer, four history header, two dashboard header. The user approved the fixes. Task-014 implementation is complete; the owner reports 2 registration, 10 history, and 2 shell regression checks passing, with scoped analyzer/MCP/diff checks clean. Task-020 normal-width visual checks passed for Home, history, and OTP; task-021’s independent 320px/2× layout checks remain in progress.
- **22 stale assertion/timing cases, TEST-005, approved for test-only updates:** 18 assertions tied to changed layouts/labels and four Buyer-chat scroll-settle/current-label assertions. Task 016’s settled-scroll diagnostics show the Buyer-chat action opens on both snapshots; the V2 tests tap before settling and base HEAD then fails an old exact-header assertion. User approved the six-file test-only update assigned to task-022. Production edits and changes to the eight base-identical failures are excluded.
- **8 failures identical on base HEAD:** two chat-image pagination cases and six direct-delivery-controller cases. The same outcomes occur on both snapshots; no product change is proposed for these baseline failures.

## Approved fix retests and current status

- **TEST-004:** The approved uncertain pickup timeout/reopen retry dead-end was implemented by task-015. The owner reports six pickup-screen and eight controller checks passing. Independent task-019 retested those six screen and eight controller cases and reports pass plus scoped analyzer clean. See [TEST-004 independent retest](../../build/stitch-ui/independent-test/run-20261112-03/TEST-004-RETEST.md). This is focused retest evidence, not a full-suite pass.
- **UI-001:** The approved decorative QR icon removal was implemented by task-013. Independent task-017 visually retested the supplied capture and reports pass. See [UI-001 retest](flutter-ui-audit-2026-11-12.md#remediation--2026-11-12-ui-001) and [retest evidence](../../build/stitch-ui/independent-ui-review/UI-001-retest.md). Large-text, interaction, live-server, and device acceptance remain unverified.
- **TEST-001–003:** The approved responsive changes are implemented by task-014. The owner reports 2 registration, 10 history, and 2 shell regression checks passing. Independent task-021 reports 14/14 targeted checks pass and scoped analyzer clean; see [TEST-001–003 retest](../../build/stitch-ui/independent-test/run-20261112-04/TEST-001-003-RETEST.md). Task-020 normal-width visual checks passed for Home, history, and OTP; see [visual retest](../../build/stitch-ui/independent-ui-review/TEST-001-003-visual-retest.md). The Home test fixture uses generatedAt=null, so source review confirms the dynamic timestamp path; the final tester run will exercise a populated variant. The normal-width captures do not cover 320px/2× visually.

The full-suite run in this report uses the pre-fix isolated source snapshot. No full-suite rerun after approved changes is recorded. User approved TEST-005 test-only changes and task-022 is in progress; no production changes are in that scope. No deployed API, installed APK, browser/camera, assistive-technology acceptance, or final implementation commit is claimed.

## Backend/API and runtime settings

Backend/API contracts are unchanged: platform `1858785e`, Auth `4c3f504`, registration `27a6361` with `automatic-registration-v2`, policy consent `policy-consent-batch-v1` / `6693b0cc9172981fa2370e3cc4e1fe6e9aec7f93`, maps `51d9694`, failed attempts `4d8bfef`, and media `28fc740`. Deployed revision remains unknown. The tester requested GPT-6 Luna/max; effective runtime settings remain unverified.


## Task 021 completion and task 022 correction addendum — 2026-11-12 (r007)

The earlier Task 016 attribution section recorded task-021 as still running. Task-021 has since completed 14/14 focused responsive cases (2 registration, 10 history, 2 shell) with scoped analyzer clean; see [TEST-001–003 retest](../../build/stitch-ui/independent-test/run-20261112-04/TEST-001-003-RETEST.md). Task-020 also passed normal-width visual review for Home, history, and OTP; the captures do not cover 320px/2× visual comparison. The Home fixture used generatedAt=null, so a populated timestamp variant remains for the fresh final tester run.

Task-022 has completed the user-approved TEST-005 test-only corrections across six test files. Its handoff reports 59/59 focused checks passing, scoped analyzer clean, and diff check clean; no production source changes were made in that task. The 8 failures reproduced unchanged on base remain excluded from this correction. Task-023 is running the fresh asset-enabled full suite and the populated Home timestamp variant. Its result is pending. The 1,346-event / 38-failure count above belongs to the pre-fix snapshot and is not the post-fix result.



## Final independent verification — task-023 (r008)

The final independent run is recorded in [Task 023’s report](../../build/stitch-ui/independent-test/run-20261112-05/FINAL-VERIFICATION.md); its [full-suite JSON](../../build/stitch-ui/independent-test/run-20261112-05/full-tests.jsonl) and [populated Home JSON](../../build/stitch-ui/independent-test/run-20261112-05/populated-home-header.jsonl) are preserved with the run artifacts.

| Check | Result |
| --- | --- |
| Full analyzer | Exit 0; `No issues found!` |
| Asset-enabled full Flutter test suite | Exit 1; 1,347 `testDone` events: 1,339 success, 2 error, 6 failure. The 1,231 named cases had 1,223 pass and 8 fail; 116 hidden file-loading events succeeded; no tests were skipped. |
| TEST-005 six-file scope | 59/59 named cases passed. No test was removed or skipped, and no skip annotation was added. |
| Populated Home header/action check | 4/4 passed at 390×844/1× and 320×640/2×, in light and dark themes. Both timestamps and both View all actions were found; labels, enabled callbacks, visible bounds, minimum 48×48 target sizes, and accessibility checks passed. |

All eight full-suite failures match the Task-016 base-targeted cases exactly by test name, result, messages, and counts: two chat-image pagination cases and six direct-delivery controller cases. The matching evidence is limited to those base-targeted cases; no new failure or product finding was reported. The suite exits 1 for these existing cases and is not a full-suite pass.

The named approved scopes are resolved and pass their recorded independent checks: UI-001 visual retest; TEST-001–003 14/14 responsive retest plus the populated Home check above; TEST-004 six screen plus eight controller checks; and TEST-005 59/59 across its six files. There is no pending approval for a named finding.

The final run used an isolated source copy with synthetic public configuration; the original `.env` and signing material were neither read nor copied. Its temporary populated-Home test was removed from the isolated copy after capture. No deployed API, live server, build/APK, available hot-reload app, installed-device, browser/camera/upload, large-text visual screenshot, or assistive-technology acceptance was performed. Backend/API contracts remain unchanged: platform `1858785e`, Auth `4c3f504`, registration `27a6361` / `automatic-registration-v2`, policy consent `policy-consent-batch-v1` / `6693b0cc9172981fa2370e3cc4e1fe6e9aec7f93`, maps `51d9694`, failed attempts `4d8bfef`, and media `28fc740`; deployed revision remains unknown. The branch remains `feature/courier-stitch-v2-implementation` at HEAD `1dc83bcc744df34da3c692c6af9120956487dac9`. The Lead’s implementation commit is pending after this documentation checkpoint.

Requested model/effort across the work was GPT-6 Luna/max; effective runtime settings remain unverified.


## Staged documentation validation clarification — r009

The r008 clean-check statement is scoped to the 76 staged Dart source/test files, all of which byte-match the isolated run-05 snapshot. After project documentation was staged, the repository-wide `git diff --cached --check` reported one warning only: `docs/logs/PROGRESS-2026-11-12.md:160 new blank line at EOF`. The historical archive remains unchanged as required; all other staged paths pass. No application source/test changes were made after final verification. The implementation commit remains pending with the Lead.
