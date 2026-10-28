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


## 2026-10-15 — G26 real media runtime and Android acceptance

- Added test-only runtime/browser/Android fixtures using production repositories/media widgets/native adapters and memory-only generated credentials. Image send/replay, MP4 seek/background/temporary cleanup, Save As cancel/picker-failure recovery/exact export and actual bearer logout pass. Production source/API/schema/dependencies and media adoption `28fc740` are unchanged; real runtime API source is `e6dc2cb4a7322dc3c5be649f467460c7e1114328`.
- Fresh verification: Courier 106 and Buyer 64 focused tests, clean analyzers, Laravel 17 tests/314 assertions, six isolation guards, 16 real storage/queue/FFmpeg/ClamAV/relationship checks, eight connected Chromium and six installed API 35 emulator checks per app; standard web/release APK and test builds pass. See [G26 evidence](references/private-media-runtime-verification.md).
- Synchronized canonical/portable evidence. Isolated local media acceptance is verified; deployed API/client pairs/Azure and production scanner/worker operations, physical devices/provider write failures/TalkBack, full-app login/account switching and signing remain open. Historical evidence is preserved; generated artifacts remain ignored.

## 2026-10-15 — Public dotenv configuration

- Replaced the production API Dart define with startup loading of the bundled `.env` and the four public keys in `.env.example`: `MAPS_ENABLED`, `GEOAPIFY_API_KEY`, `API_BASE_URL`, and `STOREFRONT_ORIGIN`. Added no dependencies. Blank API/maps settings retain the existing localhost/enabled defaults; explicit disabled maps suppress rendering and style/tile requests while retaining route stops/actions. Geoapify/storefront values are optional and currently unused; maps retain the authenticated backend proxy.
- Updated setup/CI and the route-map guide, documented the publicly readable asset boundary, and preserved the existing startup retry and map-unavailable presentation/navigation. The local secret-bearing `.env` was never opened, copied, changed, or committed. Pre-existing dependency upgrades and web-server configuration remain separate from this feature commit.
- Verification: final Flutter analyzer reports no issues; all 1,000 tests pass in an isolated copy using committed dependencies and synthetic public configuration. The final working-tree loader/startup/map regression run also passes all 20 checks without building local assets. Verified synthetic `.env` asset bytes/manifest, Git whitespace, and the unchanged 230-line Auth spec. No application release builds, live/deployed API, installed-device/browser checks, or hot restart were performed; DTD discovery found no running app.
- Backend/API unchanged: registration implementation `27a6361` / registration-email v1, route maps `51d9694`, and media adoption `28fc740` with acceptance source `e6dc2cb4a7322dc3c5be649f467460c7e1114328`. No endpoint, DTO, permission, or copied feature-contract changes. Created `feature/courier-dotenv-config` from the current Flutter branch before implementation.

## 2026-10-16 — Android release API environment selection

- Android release APKs, app bundles and Android `flutter run --release` now select `DEPLOYED_API_URL` from the existing dotenv asset. Debug/profile runs and web/desktop builds keep `API_BASE_URL` and its local default. Android releases require an HTTPS origin without credentials, API paths, queries or fragments; invalid/missing configuration reaches the existing startup retry screen without exposing values or falling back to localhost. Documented setup and standard APK builds; added no dependencies.
- Verification: final Flutter analyzer reports no issues; all 60 focused configuration, startup-retry and disabled-map regression checks pass with synthetic public values and `--no-test-assets`. Covered platform/build selection, Android browser exclusion, missing/blank/malformed/insecure deployed origins, parser redaction, quoted origins, ports, trailing slashes and `/api/v1` query construction. Dart formatting, Git whitespace and the unchanged 230-line Auth spec were checked. The local `.env` was never opened, copied, changed or committed; no APK rebuild, installed-device or deployed-API acceptance was performed.
- Backend/API baseline unchanged: registration implementation `27a6361` / registration-email v1, Auth adoption `4c3f504`, route maps `51d9694`, media adoption `28fc740` with runtime acceptance source `e6dc2cb4a7322dc3c5be649f467460c7e1114328`. No endpoint, DTO, permission or copied-contract changes. Created `feature/courier-android-release-api` from `feature/courier-dotenv-config` before implementation.

## 2026-10-17 — Pickup route empty fallback

- Reproduced and fixed map fallback messages promising absent route stops, pickup empty states implying no assigned work, and malformed stop lists being silently treated as empty. Empty routes now explain their state and offer primary Back to pickup tasks with secondary Refresh route; returned stops remain readable without a working map. Existing Navigator return preserves schedule/tasks/scroll, and invalid non-null stop-list types use recoverable contract-error handling. See [issue and verification](reports/pickup-route-fallback-2026-10-17.md).
- Verification: Flutter analyzer has no issues; all 169 affected pickup/route-map tests pass, including 60 new parsing, empty-state, recovery, keyboard/navigation, cooldown, scope/session-loss and accessibility checks. Covered all four empty route states at 320×640/390×844, 1×/2× text, light/dark; missing-coordinate/disabled/failed map checks preserve stops. Dart formatting, Git whitespace and the unchanged 230-line pickup spec were checked. No running app was found for hot reload; installed-device/browser, assistive-technology and deployed map/API acceptance remain unverified.
- Backend/API unchanged: pickup spec v2.11 / `first-and-final-mile-pickup-v1-tracking-id` at `d5c160d4a5a21272e487b6f46a82de35e81395cb`, maps `51d96947569d1603fdfb6d264ebd2a04bf866280`; latest recorded registration implementation remains `27a6361`. No endpoint, permission, transition, dependency, environment or copied-contract changes. Created `fix/pickup-route-empty-fallback` from `main` before edits; the reported server-side cause of map/stop unavailability remains unverified.

## 2026-10-26 — Platform parcel, delivery, linehaul and media sync

- Adopted platform `1858785e`: individual parcel decisions/current membership and partial routes; direct accepted-task photo/COD/Delivered submission with exact partial/lost-response recovery and refresh locks; assigned linehaul jobs/routes and confirmed departure/arrival; revised JPEG/PNG chat bounds. Preserved first-mile, historical media, auth/configuration/design and Logistics authority; no dependencies or backend/schema changes.
- Verification: clean analyzer, full suite 1,146 passes, 378 focused passes plus 35 final refresh-guard checks; isolated web/release APK builds and 18 Chromium layout/journey checks pass. Reviewed screenshots and actual synthetic proof decoding. [Evidence and commands](references/platform-sync-2026-10-26.md) distinguish local checks from deployed/provider and installed Android/TalkBack/signing gates, which remain open. No device/emulator was attached; original environment files were not read/copied/modified.

## 2026-10-28 — AISLEY Rider Google Stitch design references

- Created private Stitch project `13625567050207019759` named AISLEY Rider. Generated 16 mobile references covering Home, Work, offered task details, pickup matching, delivery photo/COD, task messages/thread, Account, sign-in, email-first registration, final-mile batches, history, notifications, route fallback, linehaul and pending delivery review. Saved PNG exports, screen/file IDs, prompts, tool descriptions, design context and correction requests in [docs/stitch](stitch/README.md).
- Reviewed source/theme, relevant contracts and the historical synthetic Home capture. Flagged generated unsupported capabilities/copy and requested core plus auxiliary refinements. Seven auxiliary variants add 23 total PNG exports; six show principal corrections, while the registration variant is rejected because its form disappeared. Core edit acknowledgments remain distinct from screenshot evidence: the Home re-download is byte-identical. Draft PNGs are not approved implementation designs; see [review](stitch/REVIEW.md).
- Backend/API unchanged: platform adoption `1858785e`; separately adopted Auth `4c3f504`, registration `27a6361` / registration-email v1, maps `51d9694`, failed attempts `4d8bfef`, media `28fc740`. Flutter inspected at `a4f17bab5dd337c4a34f0a2d7f374cf12a91d003`; deployed revision remains unknown. Created documentation branch `docs/aisley-rider-stitch-designs` before local writes.
- Documentation/export checks cover JSON, unique IDs, PNG signatures/dimensions/hashes, local links, spec line-count inventory, unchanged application source and whitespace. Pre-existing deferred specs exceed the line-count rule; see the Stitch review. Stitch listing exposes four core screens while individual retrieval preserves all 16 references. No Flutter code, frontend assets, dependencies, API/DTOs, copied feature contracts or environment files changed. No analyzer/tests/builds, live API, fresh Flutter runtime, installed-device or accessibility acceptance was rerun for this design-only task.


## 2026-10-29 — Scan-only pickup verification

- Removed manual identifier entry/type selection from first-mile pickup. Camera QR/Code 128 capture selects the type automatically, displays a read-only candidate and Scan again, and enables explicit Confirm pickup only for a nonempty candidate of at most 128 characters. QR matching, cancellation, idempotent retries, server authority and task-bound final-mile handoff remain intact.
- Enlarged the camera guide from 280×150 to a responsive square (min of 85% preview width and preview height minus 32px), retaining full-preview detection. Instructions scroll within 35% of available height so large text cannot consume the camera preview. Removed manual-entry fallback buttons/copy; camera errors explain recovery and Back.
- Verification: Flutter analyzer and all 25 focused scanning/pickup-screen tests pass; scanner/candidate/pickup interaction coverage includes capture, cancellation, automatic types, mismatch/rescan, read-only review, no mutation before confirmation, camera failures, and 320×640/390×844/640×320 light/dark at 1×/2× text. Broad scanning/pickup run: 127 pass, one existing route cooldown test fails because it expects TextButton for the unchanged OutlinedButton refresh control; isolated reproduction confirms the same failure. No unrelated route changes were made.
- Backend/API unchanged: pickup v1 tracking-ID at `d5c160d4a5a21272e487b6f46a82de35e81395cb`, platform adoption `1858785e`; local pickup spec v2.13 records the Flutter-only scan UI while retaining backend manual compatibility (230 lines). No dependencies, endpoint/DTO/permission changes or environment-file access. Reviewed familiar navigation, visible labels/results, action guards and text scaling against the design guide. Only Linux is connected; installed Android/browser camera, assistive technology and deployed API acceptance remain unverified. Branch: `feature/courier-scan-only-verification`.

## 2026-10-29 — Support-ticket notifications and inbox categories

- Synced the Courier support-ticket and notification contracts for safe in-app ticket alerts and role-specific category filtering. The Courier focused suite (90 tests) and `flutter analyze --no-pub` pass; no installed device, deployed API, or Flutter build acceptance is claimed.
- Independent contract review found both Buyer and Courier parsers reject nullable redacted resource fields (TCK-NOTIF-001, P2); disposition is pending. API validation used isolated SQLite; PostgreSQL/live acceptance remains open.

## 2026-10-29 — Nullable notification projections

- Courier now handles nullable/redacted notification resource fields without treating a missing destination as navigable. The implementation suite (116 tests), analyzer, and diff checks pass per implementor; independent retesting is running. No installed-device, build, deployed API, or live acceptance is claimed.

## 2026-10-29 — Independent nullable-notification retest

- Independent tester confirms Courier accepts the saved nullable-resource reproduction with no new findings; 62 repository/target/navigation/screen checks pass. No app build, environment access, live API, or device acceptance occurred. Buyer retest also passed; see the main progress log for its separate result.
