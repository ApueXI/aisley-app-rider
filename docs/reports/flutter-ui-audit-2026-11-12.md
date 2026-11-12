# Courier Flutter UI audit — 2026-11-12

## Baseline and scope

- Audited Git revision and branch: `1dc83bcc744df34da3c692c6af9120956487dac9`, `feature/courier-stitch-v2-implementation`.
- Working tree: not clean before this audit. Existing uncommitted changes include the V2 Flutter implementation, screenshot harnesses/fixtures, tests, and untracked `docs/stitch/v2/IMPLEMENTATION.md`; these are the supplied baseline and were not edited. The only audit artifact is this file under `build/`.
- Backend/API contracts: the latest progress entry is the 2026-11-12 Stitch exploration. Relevant adopted baselines include platform `1858785e`, Auth `4c3f504`, registration `27a6361` plus `automatic-registration-v2`, policy consent `policy-consent-batch-v1` / `6693b0cc9172981fa2370e3cc4e1fe6e9aec7f93`, maps `51d9694`, failed attempts `4d8bfef`, and media `28fc740`. The deployed API revision remains unknown. The implementation branch records no backend/API change.
- Requested scope: compare all 16 latest V3 Stitch references with the supplied synthetic Flutter captures, applying the corrections in `docs/stitch/v2/REVIEW.md` and the target mapping in `docs/stitch/v2/IMPLEMENTATION.md` (checkpoint r005; capture availability is recorded, independent verification pending).
- Actual coverage: all 16 reference families were visually inspected against the mapped outputs below. I also inspected the Courier design guide, review corrections, capture harnesses, and focused source for consent rendering, notifications, history, batch actions, and pickup scan type labeling. No app was launched, no screenshot was regenerated, and no tests or builds were run.
- Skills used: `courier-ui-review` in read-only audit mode, including its report template; orchestrator UI reviewer role plus its discovery/contracts references. These apply because this is an evidence-based Courier Flutter screen review. The web-focused design taste skill was not selected; the Courier design guide and project UI review skill own this native Flutter task.
- Runtime settings: the lead requested `gpt6luna/max`; effective model/effort metadata was not exposed to this reviewer and is unverified.

## Coverage inventory

| Screen/route/component | Owning contract | States reviewed | Evidence method | Coverage and remaining work |
| --- | --- | --- | --- | --- |
| Home | `docs/features/courier/dashboard/specs.md` | Active/available previews; stale cached section; notification entry | [RUNTIME] `v3-home.png` vs `shell/home.png` | Reviewed; no invented area/city was added. |
| Work | Dashboard spec; `docs/design-courier.md` | Five workflow rows; selected Work tab | [RUNTIME] `v3-work.png` vs `shell/work.png` | Reviewed; sans-serif is the documented correction. |
| Offered task details | `docs/features/courier/accept-delivery-requests/specs.md` | Offered final-mile parcel; accept/reject/message choices | [RUNTIME] `v3-task-details.png` vs `operations/03-offered-parcel-decision.png` | Reviewed; area-safe context and one dominant Accept action. |
| Pickup scan review | `docs/features/courier/pick-up-order/specs.md` | Read-only Code 128 candidate; rescan; explicit confirmation | [RUNTIME] `v3-pickup-scan-review.png` vs `operations/04-pickup-matched-candidate.png`; [SOURCE] scan presentation | Reviewed; one P3 icon mismatch remains (UI-001). |
| Delivery photo and cash | Delivery, proof-of-delivery, complete-delivery specs; `docs/flutter-file-uploads.md` | Task context; selected photo; unchecked COD; Delivered prerequisite/helper | [RUNTIME] `v3-delivery-photo-and-cash.png` vs `operations/05a`, `05b`, `05-delivery-cod-unchecked`, and `05c` | Reviewed across multiple scroll states; private destination/contact context and real preview/actions are present in synthetic evidence. |
| Task messages | `docs/features/courier/chat-messaging/specs.md` | Task-linked unread/read rows | [RUNTIME] `v3-task-messages.png` vs `task-003-after-final-20261112/messages.png` | Reviewed; capture uses the real Dashboard shell with synthetic message data. Live exchange and keyboard behavior not checked. |
| Registration OTP | `docs/features/courier/auth/spec.md`; registration requirements | Empty one-field OTP; resend cooldown; Back to review; server-confirmed pending explanation | [RUNTIME] `v3-registration-otp.png` vs `task-003-after-final-20261112/registration-otp.png` | Reviewed; no separate-box or activation claim. Submission behavior not exercised. |
| Sign in | Auth spec | Empty email/password; visibility affordance; Sign in/Create account | [RUNTIME] `v3-sign-in.png` vs `task-003-after-final-20261112/sign-in.png` | Reviewed; no password recovery, filled secret, or unsupported guarantee. |
| Account | `docs/features/courier/account-management/specs.md` | Identity/affiliation; grouped settings; Appearance; sign out | [RUNTIME] `v3-account.png` vs `shell/account.png` | Reviewed; initials and existing grouped flows retained. Dialog behavior not exercised. |
| Delivery history | `docs/features/courier/delivery-history/specs.md` | Exact-reference search/result; delivered/proof summary | [RUNTIME] `v3-delivery-history.png` vs `task-003-after-final-20261112/history.png` | Reviewed; no copy/archive/verified-query claim. Detail-route interaction not exercised. |
| Final-mile batches | Acceptance and delivery specs | Three synthetic parcel rows; independent accepted/offered states; accepted-only route | [RUNTIME] `v3-final-mile-batches.png` vs `operations/11-final-mile-batch.png` | Reviewed; no bulk acceptance, invented sectors, weights, or full street. Decision taps not exercised. |
| Notifications | `docs/features/courier/notification/specs.md` | All/read/unread controls, category filter, unread/read rows | [RUNTIME] `v3-notifications.png` vs `task-003-after-final-20261112/notifications.png`; [SOURCE] target resolver | Reviewed; actual All filter coherently includes the read row; linehaul category has no supported navigation target. Mark-read behavior not exercised. |
| Pickup route unavailable | Pickup spec; `docs/courier-route-maps.md` | Empty route explanation; Back to pickup tasks; Refresh route | [RUNTIME] `v3-pickup-route-unavailable.png` vs `operations/14-route-fallback.png` | Reviewed; no invented cause and no implication that assigned work is empty. Refresh action not exercised. |
| Linehaul arrival reported | `docs/linehaul-trips.md`; Logistics domain | Origin/destination; reported arrival time; waiting for Logistics receipt | [RUNTIME] `v3-linehaul-arrival-reported.png` vs `operations/15-linehaul-trip.png` | Reviewed; no gate, staging, manifest, custody-transfer, or parcel-receipt claim. Live API not checked. |
| Delivery awaiting review | Delivery, proof-of-delivery, complete-delivery specs | Pending review; submitted photo; COD included in separate capture; explicit refresh | [RUNTIME] `v3-delivery-awaiting-review.png` vs `operations/16` and `16b` | Reviewed across top and scrolled content; no automated inspection, turnaround, drop-off time, cargo release, or delivered/paid claim. |
| Policies consent | Shared policy-viewing-consent spec; Auth spec | Full document reading scroll; two unchecked version-bound selections; one Accept; sign-out recovery | [RUNTIME] `v3-policies-consent.png` vs both task-003 policy captures; [SOURCE] policy screen/card | Reviewed across reading and confirmation scroll states. Fixture legal copy is intentionally neutral; actual current server text was not fetched. |

## Checks and verification gaps

| Screen/state | Viewport | Text scale | Theme | Evidence/check and result | Gap or limitation |
| --- | --- | --- | --- | --- | --- |
| Home, Work, Account; offered task, scan review, batch, route fallback, linehaul, pending review | 390×884 logical; shell/operations PNGs are 780×1768 at DPR 2 | Default 1× | Light | [RUNTIME] Existing synthetic Flutter widget captures visually inspected at matching logical width. | No recapture, 320px, dark theme, 2× text, landscape, focus, semantics, contrast measurement, or device/browser run. |
| Delivery context/photo/COD/action states | 390×947 logical; PNGs 780×1894 at DPR 2 | Default 1× | Light | [RUNTIME] Four supplied synthetic captures cover context, selected preview, unchecked COD, and lower action state. | Scroll offsets are not recorded; no runtime photo picker/camera/upload or keyboard check. |
| Sign in, OTP, task messages, history, notifications | 390×844 logical; PNGs 390×844 at DPR 1 | Default 1× | Light | [RUNTIME] Existing task-003 captures visually inspected. Messages capture is the real Dashboard shell with synthetic data. | Reference logical height is 884; captures are 40px shorter. No vertical stretching was used. No interaction or dark/large-text check. |
| Policy reading and confirmation | 390×844 logical; PNGs 390×844 at DPR 1 | Default 1× | Light | [RUNTIME] First capture shows the reading entry; second is scrolled to privacy text/confirmation; two boxes remain unchecked and action is `Accept`. [SOURCE] The screen renders each returned policy's complete `document.version.content`. | Fixture content explicitly says it is not an AISLEY policy; deployed Terms/Privacy text, reading comprehension, contrast, focus, and large-text behavior are not verified here. |

The V3 references are 780px wide with variable full-content heights. Comparisons used 390 logical-pixel width and preserved image aspect ratio; no height scaling or raw pixel-equality claim was used. All supplied captures are light-theme default-text-scale evidence. The reference/actual comparisons are structural and visual, not pixel-perfect certification.

No automated command was run. In particular, Flutter tests/analyzer/builds, live API, installed Android, browser, camera/upload, TalkBack/VoiceOver, keyboard, focus-order, semantics, dark-theme, and 2× text acceptance are not verified. Screenshot assets establish visible layout only; they do not prove hit targets, navigation, or mutation behavior.

## Findings

### UI-001 — Code 128 candidate uses a QR-specific icon

- Priority: P3; minor visual mismatch with low potential to confuse because the adjacent type label explicitly says “Code 128”.
- Confidence: confirmed mismatch in the supplied synthetic capture and source; no user interaction was exercised.
- Screen/state and source: Pickup scan review, detected-type label; `lib/features/pickup/presentation/components/pickup_task_actions.dart:274-295`.
- Evidence: [RUNTIME] `build/stitch-ui/v2-implementation/after/operations/04-pickup-matched-candidate.png` shows a QR-shaped icon beside “Automatically detected: Code 128”. [SOURCE] line 293 uses `Icons.qr_code_scanner`. `docs/stitch/v2/REVIEW.md` under “Pickup scan review” directs removal of fake QR decoration. The candidate and server-confirmation explanation remain accurate.
- User impact: a courier may infer a QR capture from the icon while reviewing a Code 128 tracking ID; the text currently mitigates the ambiguity.
- Applicable rule: `docs/stitch/v2/REVIEW.md` — pickup scan correction; `docs/design-courier.md` — keep icon/status meaning consistent and do not imply server verification.
- Recommended change: use a neutral barcode/type indicator or omit the icon while retaining the explicit detected type.
- Acceptance criteria: a Code 128 candidate has no QR-specific visual; detected type remains readable; candidate remains read-only; `Confirm pickup` remains the explicit server-authorized action. Review at the same 390×884 logical capture and at large text scale.
- Related findings/dependencies: none.

## Prioritized implementation order

| Order | Findings to fix together | Proposed change | Acceptance/checks | Dependencies |
| --- | --- | --- | --- | --- |
| 1 | UI-001 | Replace or remove only the QR-specific type icon. | Reinspect the Code 128 candidate capture at 390×884 and large text; preserve the read-only candidate and explicit confirmation boundary. | None. Implementation requires the lead to obtain explicit user approval for UI-001. |

## Contract gaps and handoff

No API/permission/status gap was found in the 16 visible screen families. The screenshots do not authorize changes to server behavior. The area field is absent from Home because the aggregate projection has no area; avoiding a fabricated city is correct. Delivery captures include the authorized destination/contact/instruction context needed for the active task. The notification target allow-list supports pickup schedules, final-mile tasks, and support tickets; linehaul may appear as a category but has no supported linehaul navigation target.

For policies, Flutter source loops through supported Terms and Privacy items and renders the full server-provided content. The screenshots use neutral synthetic fixture text, explicitly labelled as not AISLEY policy text. Deployed current legal content and server behavior were not checked, so the screenshot cannot verify the legal wording itself.

The current r005 `docs/stitch/v2/IMPLEMENTATION.md` links before/after captures for all 16 families and correctly records “Captures available; independent verification pending.” This report supplies the UI-review result; any other independent check and device/browser acceptance remain pending. No stale capture-handoff concern remains. All other differences observed are authorized corrections (sans-serif Work, area-safe Home, actual task context, retained photo preview/actions, split scroll captures, and exact `Accept`) or synthetic fixture data, not findings.

Recommendations are not approval to implement. UI-001 has been sent to the lead for the required user-approval gate. Device/browser/assistive-technology acceptance and the full responsive/theme/state matrix remain outstanding.

## Post-review disposition — 2026-11-12

This permanent report preserves the completed read-only visual comparison in [the reviewer’s temporary report](../../build/stitch-ui/independent-ui-review/report.md). The UI reviewer completed all 16 V3 comparisons. The report’s sole finding is UI-001, P3: a QR-specific decorative icon appears beside the Code 128 scan type.

- **Approval:** The Lead requested user approval to remove the decorative QR-specific icon. Approval is pending. No code change or remediation was authorized or made.
- **Matrix:** [The V2 implementation matrix](../stitch/v2/IMPLEMENTATION.md) records all 16 visual reviews, UI-001 as pending approval for pickup scan, and independent automated-test triage as pending for every target.
- **Separate independent test status:** The Lead reports the fresh isolated-copy analyzer found no issues. The first full test attempt with `--no-test-assets` stopped at harness startup because a Flutter shader asset was unavailable. The asset-enabled full suite then ran 1,192 tests with 38 failures. Stable finding IDs and root-cause triage are in progress; examples include a Courier shell overflow at 390px/1×/light and Auth v2.6 blocked-state destination assertions. These are not final findings or approved remediation scope. The original `.env` was excluded and unread; the retry used an isolated synthetic copy with public example configuration.
- **Remaining verification:** No final independent-test report is available. Device/runtime, browser, camera/upload, keyboard, focus/semantics, dark-theme, 2× text, and assistive-technology acceptance remain unverified, as detailed above. No pixel-perfect or 100% fidelity claim is made.
- **Progress log:** `docs/PROGRESS.md` remains at 150 physical lines and is unchanged. The Lead directed deferring its dated entry until independent-test triage and the UI-001 user decision are resolved.
- **Runtime settings:** Requested `gpt-6-luna` / `max`; effective reviewer settings were not exposed and remain unverified.

The Documentor copied and published this report without rerunning tests, changing application source/tests, or implementing UI-001.

## Publication note

The Baseline section describes the reviewer’s worktree at audit time. “The only audit artifact is this file under build” refers to the temporary report then; this permanent copy was published afterward by the Documentor. Likewise, the r005 matrix status quoted above describes the review-start baseline. The linked r006 matrix records the completed 16-family UI review and current independent-test triage. The later test-run status is separate [AUTOMATED] evidence reported by the Lead; no automated check was run by the UI reviewer or Documentor.

## Remediation — 2026-11-12 (UI-001)

- Request: user-approved removal of the QR-specific icon from UI-001 in this report.
- Current Git baseline/branch: `1dc83bcc744df34da3c692c6af9120956487dac9`, `feature/courier-stitch-v2-implementation`; approved UI changes are in the uncommitted working tree.
- Backend/API version: unchanged platform `1858785e`, Auth `4c3f504`, registration `27a6361` / `automatic-registration-v2`, consent `policy-consent-batch-v1` / `6693b0cc9172981fa2370e3cc4e1fe6e9aec7f93`, maps `51d9694`, failed attempts `4d8bfef`, and media `28fc740`.

| Finding | Current-code revalidation | Changes/source | Checks and outcome | Remaining limitations/status |
| --- | --- | --- | --- | --- |
| UI-001 | Already resolved in the approved working tree. The scan-type chip retains “Automatically detected: Code 128” without the QR-specific icon. | Task-013 removed the decorative icon in `lib/features/pickup/presentation/components/pickup_task_actions.dart`; the label is now text-only. Candidate remains read-only and explicit Confirm pickup is unchanged. | [RUNTIME] Task-017 visual rereview passes the supplied 390×884 logical/DPR 2/light/default-text capture. [SOURCE] `pickup_task_actions.dart:238-253` retains detected type and Scan again; `:274-296` has no QR icon; pickup candidate/confirmation gates remain in place. See [UI-001 retest](../../build/stitch-ui/independent-ui-review/UI-001-retest.md). | No large-text, tap, network, server, app/device, or browser test was run by task-017. Independent TEST-004 retest is reported separately in the [verification report](courier-stitch-v2-verification-2026-11-12.md). No 100% fidelity claim. |

Acceptance for the approved visual correction is met in the reviewed capture: Code 128 remains explicit, the candidate remains read-only, and Confirm pickup remains the prominent server-authorized action. The V3 reference’s check-circle is not added; no match-success decoration is implied. Other open review coverage remains as listed above.

## Independent test update — 2026-11-12 (r007)

The r006 note above that said “1,192 tests with 38 failures” used an intermediate compact reporter line. It was not the final total. The final JSON contains 1,346 `testDone` events: 1,308 success, 32 error, and 6 failure (38 failing cases). See the [permanent independent verification report](courier-stitch-v2-verification-2026-11-12.md) and [Task 016 attribution](../../build/stitch-ui/independent-test/run-20261112-02/ATTRIBUTION.md).

Attribution separates eight TEST-001–003 responsive layout failures (approved; task-014 implementation complete, independent 320px/2× check pending), 22 TEST-005 stale assertion/timing cases (18 changed-layout/label assertions and four Buyer-chat scroll-settle/current-label cases, still awaiting user approval), and eight failures identical on base (two chat-image pagination and six direct-delivery-controller cases). Task-019 independently passed the approved TEST-004 pickup-screen/controller retest; a full post-fix suite has not run. Task-020 reports 390px normal-scale visual checks passing for Home, history, and OTP; task-021’s 320px/2× automated layout checks are still running. No additional product finding or TEST-005 remediation is authorized by this update.

The r006 progress statement that no dated entry had been added is historical. The r007 progress entry is appended and the former 150-line log is preserved with the new entry in [the 2026-11-12 archive](../logs/PROGRESS-2026-11-12.md). The deployed API, device/runtime, large-text, and assistive-technology acceptance limits above remain open.


## Independent retest reconciliation — 2026-11-12 (r007)

This later status supersedes the earlier r007 snapshot above while preserving its original timeline. The pre-fix full-suite JSON count remains 1,346 testDone events: 1,308 success, 32 error, and 6 failure (38 failing cases); the compact 1,192 count was intermediate. Attribution is 8 TEST-001–003 responsive layout cases, 22 TEST-005 assertion/timing cases, and 8 failures reproduced identically on base.

- **UI-001:** The approved icon removal has an independent visual PASS at 390×884 logical, DPR 2, light/default text. The scan type remains explicit and the candidate remains read-only. Large-text/device interaction remains unverified. Evidence: [UI-001 retest](../../build/stitch-ui/independent-ui-review/UI-001-retest.md).
- **TEST-001–003:** Approved responsive implementation is complete. Independent task-021 passed 14/14 focused checks with scoped analyzer clean; task-020 normal-width visual comparison passed for Home, history, and OTP. No 320px/2× visual comparison was produced. The Home fixture used generatedAt=null; the populated timestamp variant is part of the current fresh tester run. Evidence: [automated retest](../../build/stitch-ui/independent-test/run-20261112-04/TEST-001-003-RETEST.md), [visual retest](../../build/stitch-ui/independent-ui-review/TEST-001-003-visual-retest.md).
- **TEST-004:** Approved pickup timeout/reopen fix passed independent focused retest: six pickup screen and eight controller cases, with scoped analyzer clean. Evidence: [TEST-004 retest](../../build/stitch-ui/independent-test/run-20261112-03/TEST-004-RETEST.md).
- **TEST-005:** User approved test-only updates for all 22 stale assertion/timing cases. Task-022 completed six test files and reports 59/59 focused checks passing, scoped analyzer clean, and diff check clean. No production source was changed in this task. The eight base-identical failures remain outside this scope.

Task-023 is running the fresh full asset-enabled suite and a populated Home timestamp check. No post-fix full-suite result is available yet. No final implementation commit, deployed API, installed device, browser/camera, large-text, assistive-technology, or 100% fidelity claim is made. Backend/API versions remain unchanged as listed above.


## Final verification and finding closure — 2026-11-12 (r008)

The final independent verification is documented in the [permanent test report](courier-stitch-v2-verification-2026-11-12.md) and [Task 023 run report](../../build/stitch-ui/independent-test/run-20261112-05/FINAL-VERIFICATION.md). All named findings UI-001 and TEST-001–005 were approved, implemented or corrected in their assigned scopes, and passed their recorded independent checks. No named approval remains pending.

The final full analyzer exited 0 with no issues. The asset-enabled full suite exited 1 with 1,347 testDone events (1,339 success, 2 error, 6 failure); 1,223/1,231 named cases passed, and all 116 hidden file-loading events succeeded. The eight failing cases match Task-016 base-targeted test names, results, messages, and counts exactly: two chat-image pagination and six direct-delivery controller cases. No new failure or product finding was reported. The full suite therefore is not described as passing.

The final run also passed the 59/59 TEST-005 corrected cases across six files, with no tests removed or skipped. Its populated Home header/action check passed 4/4 for standard and enlarged text in light/dark themes; visible timestamp/View all semantics and 48×48 target bounds were verified. No fresh screenshot, build/APK, deployed/live API, available hot-reload app, installed-device, browser/camera/upload, large-text visual screenshot, or assistive-technology acceptance was performed. The UI audit remains a structural/visual review of synthetic captures, with no pixel-perfect or 100% fidelity claim. Backend/API baselines are unchanged and the deployed revision remains unknown. The implementation commit is pending the Lead’s post-checkpoint action.
