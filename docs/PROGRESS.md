# Courier Flutter Progress

Short, dated implementation log. Append entries; archive complete logs after 150 physical lines. Preserve historical reports and distinguish local verification from deployed/device acceptance.

## Current status

- Auth v2.6 handling, account/vehicle/policy, inbox and targeted notifications, first-mile pickup/filtering, batch acceptance/hub handoff, photo POD/COD intent, failed attempts, exact-reference history, dashboard v2 with default-v1 fallback, read-only MapLibre routes and private chat images/received MP4/documents are implemented locally. Recovery UI and linehaul screens remain unadopted.
- Historical adoption slices: Auth 4c3f504; earlier operations d7df220; maps 51d9694; failed attempts 4d8bfef; media 28fc740. Inspected source: Laravel `240eefddd4e2e2eea2f9558beec0292efa2121fe`, Courier `177eac1d1d132916cef25054cfc959e223fa409c`. Inspection does not promote every contract to client adoption; deployed revision remains unidentified.
- Live authenticated/deployed API, private-media runtime and installed Android/accessibility acceptance remain open. Media video/document upload remains outside the current mobile release.
- Historical application test/build/browser results are in the archives and verification reports. This sync runs documentation validation only.

## Historical progress

- [Platform history](logs/PROGRESS-2026-10-12.md): original dated results with their own execution scope.
- [Client history](logs/PROGRESS-2026-10-12-2.md): original dated results with their own execution scope.

## 2026-10-12 — Three-project documentation synchronization

- Reconciled server contracts with current Flutter sources, imported newer client evidence, corrected status summaries and retained explicit adoption/release gaps. Archived the two complete role histories separately with attribution; existing archives remain unchanged.
- Validated portable links/anchors, JSON/examples, endpoint inventory, spec bounds, synchronized copies, preserved archive prefixes and PSGC bytes, plus Git whitespace. See [audit and validation](references/synchronization-2026-10-12.md). No application tests/builds or live/device checks were rerun.

## 2026-10-14 — Email-verified account password changes

- Added password-code requests and the account email-verification dialog before Courier password changes. Typed API fields, resend/expiry and Retry-After, account cleanup, uncertain outcomes, unsaved-profile warnings and the existing all-device sign-out are preserved. Adopted the new password-code API contract and updated only affected documentation.
- Verification: 44 account/widget tests, Flutter analyzer, web build and Android release APK pass, including existing 320/390px light/dark and 1×/2× accessibility checks. Live SMTP/deployed API and installed-device acceptance remain open.

## 2026-10-14 — Email-first registration OTP

- Adopted registration-email contract v1 (2026-10-14): public code/verify APIs, six-digit OTP, required role/email-bound proof, resend/expiry/Retry-After, memory-only secrets, retained registration drafts and existing approval gates. Existing accounts keep their login behavior. Updated typed API models/repositories and native registration UI; no new dependencies.
- Verification: 190 auth checks, 7 app checks and targeted registration-success cleanup, Flutter analyzer, web build and Android release APK pass. Laravel registration/mail enforcement and isolated PostgreSQL concurrency checks pass independently; live SMTP/deployed API and installed-device acceptance remain open. API enforcement requires coordinated client release and the new backend migration/workers.
- Backend implementation: `27a6361`; registration-email contract v1 (2026-10-14).

## 2026-10-14 — Project-local Courier UI review skill

- Created [courier-ui-review](../.agents/skills/courier-ui-review/SKILL.md) with audit as the default, UI metadata, a report template, and an explicit improvement workflow. Reports preserve evidence and scoped finding IDs; improvements revalidate findings and resolve applicable Flutter helpers from the current catalog.
- Verification: skill-creator validator, metadata/reference checks, and instruction walkthroughs for the six requested audit, selected-finding, stale-finding, missing-runtime, backend-gap, and direct-fix scenarios pass. This is skill/documentation work only; no application audit, UI edits, or Flutter checks were performed. Changes remain uncommitted for review.
- Backend/API baseline unchanged: latest recorded backend implementation `27a6361`, registration-email contract v1 (2026-10-14). Future reviews must resolve each affected feature's current adopted contract and distinguish local checks from device/browser acceptance.

## 2026-10-14 — Whole-project Courier UI source audit

- Audited Flutter `ee62d69ac962146292093917337c68521d2e91eb` on `feature/courier-ui-review-skill`; baseline working tree was clean. Wrote [flutter-ui-audit-2026-10-14.md](reports/flutter-ui-audit-2026-10-14.md) with the screen/dialog/shared-component inventory, five confirmed source findings and one suspected chat keyboard/layout issue. Application code, tests, contracts, design guides and dependencies are unchanged; recommendations require an explicit improvement request.
- Backend/API evidence: latest recorded implementation `27a6361`, registration-email contract v1 (2026-10-14); password-code local adoption dated 2026-10-14; historical Auth `4c3f504`, operations `d7df220`, maps `51d9694`, failed attempts `4d8bfef`, media `28fc740`. Inspected/adopted records are distinguished in the report; deployed revision remains unknown.
- Checks: cached Flutter analyzer passes with no issues; Flutter test assertions could not run because the sandbox blocks the harness localhost socket (86 files failed to load). Existing accessibility matrix/assertions were inspected without claiming a rerun. Report links/spec counts, append-only progress and final scoped diff/whitespace were checked. Live/device/browser/keyboard/TalkBack acceptance and partial source coverage remain open.


## 2026-10-15 — AISLEY Courier UI/UX overhaul

- Implemented the approved four-tab navigation, work-first bounded Home, guided registration with retained drafts/error-step focus/expiry recovery, grouped Account flows, compact operational/communication lists, neutral light/dark theme, shared spacing/targets and Android/web branding. Details/forms/cameras/maps use the existing Navigator above the shell. Session-only scroll/filters persist; hidden/covered/paused screens stop polling, and session loss closes private routes and clears private state.
- Revalidated and remediated UI-001–UI-006: reproduced the old chat keyboard overflow (1,140px) before replacing its layout; immediate chat Back protection, vehicle/POD discard guards, complete authorized OR/CR previews, guarded cooldown/deduplicated private reads, and confirmed policy sign-out. Preserved the original audit evidence and appended [remediation](reports/flutter-ui-audit-2026-10-14.md#remediation--2026-10-15).
- Verification: final Flutter analyzer has no issues; all 979 tests pass, including 320×640/390×844, light/dark, 1×/2× text, wider layout, keyboard/focus/semantics/targets, navigation, notification targets, paused/hidden polling, verification expiry and session cleanup. Android release APK and web builds pass. Twelve synthetic before/after captures, build hashes, contract regression scope and spec-bound checks are in the [verification report](reports/courier-ui-overhaul-2026-10-15.md).
- Backend/API unchanged: latest recorded `27a6361`, registration-email v1; password-code local adoption 2026-10-14; separately adopted Auth `4c3f504`, operations `d7df220`, maps `51d9694`, failed attempts `4d8bfef`, media `28fc740`. No API/DTO/backend/dependency changes. Updated only the shared design conventions and overhaul evidence; deferred features remain outside scope.
- Installed Android, TalkBack/VoiceOver, same-app browser camera/upload/media and authenticated deployed API acceptance remain pending and separate from widget checks/builds. Created `feature/courier-ui-overhaul` before implementation; original audit/progress work was preserved separately as `bef3374`. Historical progress and audit prefixes remain unchanged. Implementation commit: `2049809`; verification evidence is committed separately.


## 2026-10-15 — D02 shipping context clarification

- Corrected only copied requirements, workspace and schema shipping passages against Laravel `33f668fd672226211accdbbb3b16052d9c48e592`: new Orders require complete local/planned routes; unavailable quote/placement recovery uses SHIPPING_COVERAGE_UNAVAILABLE/QUOTE_STALE. Historical unplanned prices, fulfillment/Finance holds and exact replay remain valid. Synchronized these passages to the Courier project's matching guides.
- Checked affected links, copies and whitespace; Courier source, workflows, API/DTOs, adopted revisions and prior implementation/device status remain unchanged. No Flutter tests/builds, live/deployed API or installed-device checks were rerun for this documentation-only correction.
