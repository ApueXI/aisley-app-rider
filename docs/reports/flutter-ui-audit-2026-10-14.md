# Courier Flutter UI audit — 2026-10-14

## Baseline and scope

- Requested scope: whole Courier Flutter project, audit only. This is a broad source and existing-test review, with incomplete rendered-state coverage; it is not device/browser or accessibility acceptance.
- Audited Git revision: `ee62d69ac962146292093917337c68521d2e91eb`; branch: `feature/courier-ui-review-skill`.
- Working tree before the audit: clean; no staged, unstaged, or untracked changes reported. Sources, tests, dependency/lock files, contracts, design guides and snapshots were left unchanged. Task edits are this report and an append-only progress entry.
- Local environment: Linux x64, cached Dart SDK 3.13.2, resolved project dependencies. No live authenticated account, uploaded evidence, operational mutation, preview generation or golden update was used.
- Authority: root/docs `AGENTS.md`, [design guide](../design-courier.md), [feature rules](../features/courier/rules.md), [architecture](../architecture.md), Courier-related requirements/workspace/schema sections, Courier/Logistics domains, registration/upload references and [Flutter upload boundary](../flutter-file-uploads.md).
- Latest recorded work: email-verified account password changes, email-first registration OTP and the project-local UI review skill, all dated 2026-10-14 in [PROGRESS](../PROGRESS.md). The latest recorded backend implementation is `27a6361`, registration-email contract v1 (2026-10-14).
- Adopted historical slices: Auth denial handling `4c3f504`; earlier operations `d7df220`; maps `51d9694`; failed attempts `4d8bfef`; private media `28fc740` plus the decimal-byte limit revision. These are feature-specific adoption records, not one deployed backend revision.
- Recorded source inspection from 2026-10-12: Laravel `240eefddd4e2e2eea2f9558beec0292efa2121fe`, Courier `177eac1d1d132916cef25054cfc959e223fa409c`. This audit inspected the current Flutter checkout and copied contracts; it did not reinspect the external Laravel repository. Deployed API revision is unknown. The password-code contract records local adoption but does not identify its new backend commit.
- Result: five confirmed source findings and one suspected keyboard/layout finding. No P0 issue was established within this coverage. Source confirmation proves the implementation described, not rendered pixels or assistive-technology behavior.
- Finding IDs are local to `docs/reports/flutter-ui-audit-2026-10-14.md`. Recommendations do not authorize implementation.

### Contract map

The matching implemented feature specifications and applicable endpoint notes were read. Older header commits remain historical foundations; newer linked revisions govern their documented additions.

| Area | Owning copied contract and relevant version |
| --- | --- |
| Auth/registration | [auth/spec.md](../features/courier/auth/spec.md) v2.7; Auth v2.6 denial integration at `4c3f504`; [registration-email.md](../registration-email.md) v1, backend `27a6361` |
| Account/security/photo | [account-management/specs.md](../features/courier/account-management/specs.md) v2.5, `courier-account-management-v1`, historical photo foundation `20afd9f`; [password-change.md](../password-change.md), local 2026-10-14 adoption |
| Vehicle | [Logistics vehicle-fleet-management/specs.md](../features/logistics/vehicle-fleet-management/specs.md) v2.5; separate Courier vehicle/revision/document endpoints |
| Policy | [shared/policy-viewing-consent/spec.md](../features/shared/policy-viewing-consent/spec.md) v1.4 |
| Dashboard | [dashboard/specs.md](../features/courier/dashboard/specs.md) v2.8 and [aggregate-api.md](../features/courier/dashboard/aggregate-api.md); `courier-dashboard-v2`, default scaffold v1 retained; header records `61f302c` plus a feature branch |
| Notifications | [notification/specs.md](../features/courier/notification/specs.md) v1.2, `courier-notifications-v1`; header identifies a branch rather than a release hash |
| Acceptance/batches | [accept-delivery-requests/specs.md](../features/courier/accept-delivery-requests/specs.md) v1.6, `courier-first-and-final-mile-accept-v1` |
| Pickup/scanner/manifest | [pick-up-order/specs.md](../features/courier/pick-up-order/specs.md) v2.11, `first-and-final-mile-pickup-v1-tracking-id`; header `d5c160d`; map adoption `51d9694` |
| Delivery/routes/failed attempts | [delivery-order/specs.md](../features/courier/delivery-order/specs.md) v1.9, `courier-delivery-v1-final-mile-task`; maps `51d9694`; [failed-attempts.md](../features/courier/delivery-order/failed-attempts.md), `4d8bfef` |
| POD/completion | [proof-of-delivery/specs.md](../features/courier/proof-of-delivery/specs.md) v1.9, `courier-epod-v2-photo`; [complete-delivery/specs.md](../features/courier/complete-delivery/specs.md) v1.9; photo/approval revisions supersede the historical QR version label |
| History | [delivery-history/specs.md](../features/courier/delivery-history/specs.md) v1.5, `courier-delivery-history-v1` |
| Task chat/media | [chat-messaging/specs.md](../features/courier/chat-messaging/specs.md) v2.5, [api-handoff.md](../features/courier/chat-messaging/api-handoff.md), `courier-operational-messaging-v2`; [media-api.md](../features/courier/chat-messaging/media-api.md), adopted `28fc740` |
| Support | [support-tickets/spec.md](../features/courier/support-tickets/spec.md) v1.1, `courier-support-tickets-v1`, historical header `40c68de` |

Acceptance, delivery, POD, completion and history retain the shared `d1abeee73d0141e1fd7dda4bea0ee3fead370378` foundation in their metadata. This does not replace the newer map, failed-attempt, media, password or registration slices above.

## Coverage inventory

Discovery used Dart screen/form/dialog classes, `Scaffold`, navigation calls and presentation/shared files under `lib/`, plus existing `test/` targets. Navigation uses `AuthGate` and `MaterialPageRoute`; the rows below inventory discovered destinations and nested dialogs without inventing URL routes. **Reviewed** means source behavior was inspected; **partial** identifies limited component/state depth. No row received live runtime acceptance.

| Screen/route/component | Owning contract | States reviewed | Evidence method | Coverage and remaining work |
| --- | --- | --- | --- | --- |
| Bootstrap loading/error scaffold | Architecture/Auth | Startup shell and alternate theme | [SOURCE] `lib/app/courier_bootstrap.dart` | Partial; error detail, long-text/keyboard/device behavior unverified |
| AuthGate; CheckingSessionScreen | Auth | Checking, signed out, authenticated, denial/consent routing | [SOURCE] `lib/app/courier_app.dart`; `test/widget_test.dart` inventory | Reviewed composition; full state matrix not rendered |
| LoginScreen | Auth | Fields, password visibility, submission, error/cooldown | [SOURCE] `login_screen.dart`; Auth screen-test assertions | Reviewed; only stress-pair accessibility coverage identified |
| BlockedAccessScreen (pending/rejected/suspended/affiliation/denied); RetrySessionScreen; SecureStorageFailureScreen; PolicyConsentUnavailableScreen | Auth | Explanation, retry/return action, storage failure | [SOURCE] `blocked_screen.dart`, AuthGate | Reviewed; platform assistive-technology and full matrix unverified |
| RegistrationScreen; RegistrationEmailFields; submitted/pending result | Auth/registration-email | Email/code/resend, verification gate, grouped details, PSGC/manual fallback, upload, draft exit | [SOURCE] registration composition/interaction/data; existing auth tests | Partial; OTP/details composition inspected, every validation/upload branch not individually rendered |
| Registration birth-date picker; organization/address/vehicle/evidence sections | Auth/upload references | Familiar controls, required evidence, fallback/selection | [SOURCE] registration components and matching test assertions | Partial; native picker, long selector labels and camera/file runtime unverified |
| DashboardScreen; work menu, welcome/avatar, aggregate/status cards, legacy previews, destination buttons, sign-out dialog | Dashboard/Notifications/Account | V2/legacy navigation, partial/stale/empty/failure rendering, explicit sign-out | [SOURCE] dashboard screen/body/aggregate/navigation; dashboard tests | Reviewed composition; full visual/semantics matrix and remaining private cards partial |
| AccountScreen; profile form/photo selection/preview/removal/discard; PasswordVerificationDialog | Account/password-code | Editable/read-only separation, draft guard, code/resend/expiry, password consequences, photo feedback | [SOURCE] account screen/photo view/dialog; account accessibility tests | Partial; form state/focus coverage inspected, all photo transport states not rerun |
| VehicleScreen; fields and independent OR/CR controls | Vehicle | Load/save, dirty fields, selected/current previews, recoverable failure, rate limit, Back | [SOURCE] vehicle screen/components/controllers; existing vehicle screen tests | Reviewed source; findings UI-003 through UI-005; no phone/theme/text matrix identified |
| PolicyScreen; PolicyHistoryScreen; PolicyVersionScreen | Policy | Required consent, explicit checkbox/version, stale/error/history, sign-out | [SOURCE] policy consent/history/version; existing policy test inventory | Reviewed composition; UI-006; full state/accessibility matrix unverified |
| NotificationScreen; NotificationDetailScreen | Notifications | Refresh, loaded/read/unread, related-work availability, explicit mark-read | [SOURCE] notification screen/detail and navigation/test inventory | Partial; target authorization/navigation covered in existing tests, all inbox filters/stale branches not rendered |
| FinalMileTaskEntryScreen | Notifications/Delivery/Pickup | Scoped offer/accepted/transit entry and current-state requirement | [SOURCE] destination wiring; existing navigation-state tests | Partial; owning entry implementation not completely inspected |
| PickupScreen; PickupTaskDetailScreen; schedule filter | Pickup/Acceptance | Separate legs, targeted schedule, acceptance, first-mile candidate controls, hub handoff | [SOURCE] pickup screen/detail/actions/handoff; schedule-filter tests | Partial; list/detail actions inspected, all list/state/keyboard combinations unverified |
| Pickup accept/reject dialogs; hub-handoff confirmation | Pickup/Acceptance | Confirmation, reason, pending Logistics validation | [SOURCE] action/navigation discovery and hub dialog | Partial; rejection/first-mile confirmation contents not exhaustively reviewed |
| PickupRouteScreen | Pickup/maps | Authorized route entry, map/list fallback | [SOURCE] route wiring; route-screen test assertions | Partial; stress pair exists with injected renderer; full actual renderer and all states unverified |
| BarcodeScannerScreen; unsupported/error/manual fallback | Pickup | QR/Code 128 candidate, permission/error copy, lifecycle cleanup, manual exit | [SOURCE] `lib/core/scanning/barcode_scanner_screen.dart` | Reviewed source; no hardware permission/capture or full layout matrix |
| FinalMileBatchScreen; FinalMileBatchDetailScreen; acceptance dialog/card | Acceptance | Whole-batch review, explicit acceptance, pending recovery, accepted/in-progress route link | [SOURCE] batch screen/detail/acceptance; accessibility assertions | Reviewed composition; list and remaining error-state depth partial |
| DeliveryRouteScreen | Delivery/maps | Accepted gate, advisory summary, known/missing stops, map failure, retry/consent | [SOURCE] route screen; existing route-state/accessibility tests | Reviewed composition; injected map tests do not exercise actual MapLibre rendering |
| DeliveryScreen; DeliveryTaskScreen; movement, POD/completion/COD cards and confirmation | Delivery/POD/Completion | State-specific actions, chat alternatives, local photo, pending review, explicit cash acknowledgment | [SOURCE] screen/task/photo selection; POD/accessibility tests; dialog discovery | Partial; UI-003; all movement/proof/payment failure branches not individually reviewed/rendered |
| DeliveryPhotoCameraScreen | POD | Ready/capturing, loading, permission/busy/error, file fallback, lifecycle release | [SOURCE] camera screen; fake-camera accessibility tests | Reviewed source; installed rear-camera/permission behavior unverified |
| FailedDeliveryAttemptForm/card; discard dialog | Failed-attempt handoff | Reason/note, report/exact retry, draft exit, account loss | [SOURCE] form; existing failed-attempt test inventory | Partial; card/history and all conflict/cooldown states not exhaustively reviewed |
| HistoryScreen; HistoryDetailScreen; exact-reference search | History/POD | Read-only detail, scope loss, bounded results, nullable proof, search/clear/error/stale | [SOURCE] screen/detail; history accessibility/search assertions | Partial; search behavior covered by existing tests, complete detail matrix unverified |
| ChatInboxScreen; ChatThreadScreen; message rows; leave/discard-retry dialogs | Chat | Context/leg/counterparty, draft, read-only, send/retry, polling and account cleanup | [SOURCE] chat screens/message row; existing chat tests | Reviewed source; UI-001/UI-002; full inbox/thread keyboard/layout states unverified |
| SupportTicketScreen; SupportTicketCreateScreen; SupportTicketDetailScreen; summary/event/status/list components; discard dialog | Support | Own list/create/reply/read, categories, draft/uncertain retry, unavailable return | [SOURCE] screens/create/detail; support accessibility assertions | Partial; composition reviewed, full polling/filter/state behavior not independently verified |
| Shared Material theme | Design guide | Light/dark scheme, fields/buttons/cards, system preference | [SOURCE] `lib/app/courier_theme.dart`, CourierApp | Reviewed source; rendered contrast/focus is not established by theme definitions |
| UnsavedChangesGuard; FormFieldNavigation | Design guide/Auth/Account | Keep editing/discard hierarchy, busy exit, immediate account cleanup, ordered error reveal | [SOURCE] guard; owning form wiring and existing test assertions | Guard reviewed; navigation helper partial; native Back/focus acceptance unverified |
| RouteMapView/RouteSessionBoundary; scope/data/tiles/marker support | Pickup/Delivery/maps | Known geometry, Fit route/zoom/attribution, fallback, resource/session cleanup | [SOURCE] map view/boundary; existing injected-map assertions | Partial; view/boundary reviewed, supporting transport/geometry files not fully audited |
| ChatImageComposer; PrivateChatImage; PrivatePoster; PrivateImageViewer; PrivateChatFile; PrivateVideoViewer | Chat media | Select/view, private image, explicit playback/download, retry, scope cleanup | [SOURCE] image/video viewers and file control; composer/image/media test assertions | Partial; composer/poster internals and all identity/error branches unreviewed; native Save As/browser playback unverified |
| DeliveryProofPhotoPreview and feature-private status/empty/error/loading widgets | POD/History and owning features | Preview/status composition and named recovery states | [SOURCE] owning screens and existing tests | Partial; individual visual/semantics implementations not all inspected |
| Linehaul trip screen, recovery completion, incidents, earnings, live telemetry, background push, offline writes | Owning deferred/unadopted contracts | No matching implemented client destination discovered | [SOURCE] source inventory and progress boundary | Unreviewed/not present; no recommendation to enable them |

Feature-private fields/cards/sections remain grouped with their owning screens. DTOs, repositories, networking/security, native export and map/media adapters were inspected only where needed for UI authority/recovery; this is not an exhaustive security or backend audit.

## Checks and verification gaps

### Commands actually attempted

- **[AUTOMATED]** `flutter analyze --no-pub` and `flutter test --no-pub --reporter expanded`: the SDK shell wrapper could not write its external cache stamp. These attempts did not run analysis/test assertions.
- **[AUTOMATED]** Direct cached Flutter-tool snapshot initially encountered the external cache lock restriction. A subsequent invocation with `FLUTTER_ALREADY_LOCKED=true`, `FLUTTER_SUPPRESS_ANALYTICS=true` and `--no-version-check` allowed analysis while the SDK remained read-only. Informational cache-stamp writes still emitted warnings.
- **[AUTOMATED]** Successful analysis command: `FLUTTER_ALREADY_LOCKED=true FLUTTER_SUPPRESS_ANALYTICS=true /home/cred/develop/flutter/bin/cache/dart-sdk/bin/dart /home/cred/develop/flutter/bin/cache/flutter_tools.snapshot --no-version-check analyze --no-pub`. Exit 0: **No issues found**, 6.1 seconds. This is static analysis, not UI acceptance.
- **[AUTOMATED]** The same cached-tool invocation for `test --no-pub --reporter expanded` exited 1 before assertions: the Flutter test harness could not bind `127.0.0.1` (`Operation not permitted`). All 86 discovered test files failed to load for this infrastructure reason. This is not evidence of 86 application regressions. No test result below is a current pass.
- **[AUTOMATED]** Git whitespace check passed before report creation. Final documentation/diff checks are recorded in the progress entry. No `pub get`, dependency change, application fix, new test, golden update or preview was performed.
- **[SOURCE, historical only]** PROGRESS records 2026-10-14 account/auth/app test, analyzer and web/APK build passes. They were not rerun successfully here, and those entries do not record a complete Flutter Git revision for each run. Older browser observations in verification references were not reused as current runtime evidence.

### Existing layout/state coverage inspected

`test/helpers/accessibility.dart` defines eight combinations: 320×640 and 390×844, each at 1×/2× text in light/dark production themes. Its stress subset is 320×640 at 2× in both themes. `checkAccessibility` asserts no rendering exception, Android/iOS tap-target guidelines, tap labels and text contrast; scroll checks visit overlapping viewports. These assertions do not establish TalkBack, actual keyboard occlusion, map/camera hardware, visual polish or real server behavior.

Every listed test remains **not verified in this audit** because the harness could not start. The table describes inspected assertions, not successful executions.

| Screen/state | Viewport | Text scale | Theme | Evidence/check and result | Gap or limitation |
| --- | --- | --- | --- | --- | --- |
| Registration details/draft discard | 320×640, 390×844 | 1×, 2× | Light, dark | [SOURCE] `registration_accessibility_test.dart`: eight cases; full scroll, filled form, discard/Keep editing, no submission | [AUTOMATED] Not verified; validation/organization loading/offline/retry use stress subset only |
| Email verification/code paste | 320×900, 390×900 | 2× | Light, dark | [SOURCE] `registration_email_test.dart`: code paste/leading zero, verified callback and exception checks using standard ThemeData | Not the requested heights or production-theme eight-case matrix; no current pass |
| Sign-in cooldown/keyboard submit | 320×640 | 2× | Light, dark | [SOURCE] `auth_v26_screen_test.dart`: disabled tap/keyboard submission and explicit retry after expiry; scroll guidelines | Other six combinations and all denial screens not shown to have equivalent accessibility assertions |
| Account loaded/photo/draft | 320×640, 390×844 | 1×, 2× | Light, dark | [SOURCE] `account_accessibility_test.dart`: eight cases, scroll, photo selection, draft preservation | Password-code dialog/focus and loading/offline/retry use stress subset; actual keyboard insets unverified |
| Batch detail/offered/accepted | 320×640, 390×844 | 1×, 2× | Light, dark | [SOURCE] `final_mile_batch_accessibility_test.dart`: eight cases, parcel scroll, acceptance dialog, keyboard cancel/focus restoration and no accidental accept | List/full error matrix missing; loading/offline/retry stress only |
| Delivery local photo/COD/pending intent | 320×640, 390×844 | 1×, 2× | Light, dark | [SOURCE] `delivery_accessibility_test.dart`: eight cases, camera/file control focus, photo preview, unchecked cash consent, canceled intent, pending remains undelivered | Fake repository/capture; Back with unsent photo and installed behavior not established |
| POD camera ready/permission denied | 320×640, 390×844 | 1×, 2× | Light, dark | [SOURCE] `delivery_camera_accessibility_test.dart`: eight combinations per state, guidelines, keyboard controls, session disposal | Fake camera; real permission, capture, cutouts and installed lifecycle still open |
| Delivery route/map failure | 320×640, 390×844 | 1×, 2× | Light, dark | [SOURCE] `delivery_route_screen_test.dart`: eight cases, ordered stops, Last refreshed, failure retains text and re-reads | Injected renderer; real map controls/tiles not exercised |
| Pickup route/list fallback | 320×640 | 2× | Light, dark | [SOURCE] same route test: stress pair, hub return/numbered markers, map above preserved stop list, disposal clears manifest | Other six combinations/actual rendering absent from these assertions |
| History search/bounded results | 320×640, 390×844 | 1×, 2× | Light, dark | [SOURCE] `history_accessibility_test.dart`: eight cases, keyboard Search/Clear, focus return, no unsupported pagination | Error/stale/retry stress pair; detail/private photo full matrix not established |
| Support list/create/detail/reply | 320×640, 390×844 | 1×, 2× | Light, dark | [SOURCE] `support_accessibility_test.dart`: eight cases, scroll guidelines, keyboard create/reply/read | Loading/offline/stale/filter menu stress pair; native keyboard and all server conflicts unverified |
| Notification targeted navigation/unavailable work | 320×640 | 2× | Light, dark | [SOURCE] notification navigation/state tests: bounded labels, related-work current context and safe unavailable destination | Partial entry-flow assertions, not a complete inbox/detail/state eight-case audit |
| Dashboard notice/retry | 320×700 | 2× | Test default | [SOURCE] `dashboard_summary_screen_test.dart`: live-region notice and no layout exception after failed refresh | Different height; no full production light/dark matrix or app-bar/menu guideline check |
| Chat image/history controls | 320×640 | 2× | Light, dark | [SOURCE] `chat_image_pagination_test.dart`: image labels/tap action/minimum target, older-image association and logout/consent cleanup | No keyboard inset, multiline draft/long error or fresh-text system-Back assertion identified |
| Private video/document controls | Widths 320/390/768/1440; fixture constraints | 2× | Light, dark | [SOURCE] `private_media_test.dart`: scoped playback/download cleanup, responsive control assertions; source has scrollable video controls | Not the exact two-height 1×/2× matrix; installed Save As/playback/assistive technology open |
| Vehicle | Existing default test viewport | Test default | Default MaterialApp | [SOURCE] `vehicle_screen_test.dart`: three tests for truck load/type save and separate OR/CR controls | No dedicated phone/theme/large-text, Back, full-document or cooldown UI assertions identified |
| First-mile candidate selector/scanner; policy/history; bootstrap; remaining status cards | Requested matrix not established | Not established | Not established | [SOURCE] controls/state composition and relevant existing test inventory | Rendered full matrix remains unverified; absence of coverage is not a demonstrated failure |

No runtime observations were made in this audit. Installed Android, localhost `http://localhost:8765`, live API/SMTP, physical camera permissions, actual keyboard insets, TalkBack, high-contrast settings, reduced motion and one-handed use remain acceptance work. Authenticated browser observation must retain the documented package-provided WebCrypto/encrypted LocalStorage localhost boundary; no plaintext fallback or live mutation is needed to verify layout.

## Findings

### UI-001 — Chat may lose reachable controls when the keyboard reduces available height

- **Priority:** P1 if reproduced: a large-text user may be unable to read recovery guidance or reach the composer/send control.
- **Confidence:** Suspected. Source establishes unbounded fixed-height content outside the message scroll area; overflow/occlusion has not been rendered or measured.
- **Screen/state and source:** Sendable ChatThreadScreen, multiline draft plus send error or pending-retry notice; `lib/features/chat/presentation/chat_thread_screen.dart:226` (`body: Column`), `:292` (error/retry), `:304` (composer).
- **Evidence [SOURCE]:** Only the message list is Expanded/scrollable. Task header, recovery text, pending-retry button and a field growing to four lines consume nonflexible height. With 2× text and an open keyboard, these siblings can exhaust the remaining body constraints. Existing image tests omit this keyboard/error combination.
- **User impact:** Potential inaccessible send/retry guidance and task context on small phones; not established for ordinary one-line composition.
- **Applicable rule:** Design guide, Typography and spacing / Navigation and layout / Accessibility and quality; Chat v2.5 accessible recovery requirement.
- **Recommended change:** First reproduce with synthetic data. If confirmed, bound and scroll the composer/recovery region or use the existing responsive Material layout patterns while retaining task context and one send/exact-retry action. Keep the draft and frozen send identity intact.
- **Acceptance criteria:** At both requested sizes, both scales and both themes, open a realistic keyboard inset, enter four lines, show a long recoverable send error and pending retry, and verify no overflow plus reachable Message/Send/Retry/Back and visible focused control. Check read-only and image-selection variants. An installed Android check is separate from widget assertions.
- **Dependencies:** Rendered verification required before implementing a layout fix; pair with this report's UI-002 when reviewing chat.

### UI-002 — Fresh chat text does not update the system-Back discard guard

- **Priority:** P2: accidental navigation can lose an unsent message; app-bar Back and system Back behave differently.
- **Confidence:** Confirmed source defect for text entered between parent rebuilds; installed Back behavior was not observed.
- **Screen/state and source:** Empty sendable thread → type without sending/adding images → system Back before another controller/poll notification. `lib/features/chat/presentation/chat_thread_screen.dart:31`, `:79`, `:208`, `:312`.
- **Evidence [SOURCE]:** `PopScope.canPop` depends on `_text.text.isEmpty`, but the TextEditingController has no listener that rebuilds the parent and the TextField has no `onChanged` callback. Typing updates the field without recomputing the guard. The app-bar `_leave` reads the current text and prompts, while an already-true `canPop` permits direct system exit; dispose drops the local controller.
- **User impact:** Unsent plain-text drafts can disappear without the implemented Leave conversation confirmation. Subsequent polling may mask the defect, making protection intermittent.
- **Applicable rule:** Design guide, Familiar patterns and focused decisions / Components and interaction patterns: consistent Back and confirmation before unsaved work is discarded.
- **Recommended change:** Make dirty-state/PopScope rebuild on text changes, reusing the existing draft-protection pattern. Preserve the special behavior for unresolved sends and immediate account cleanup.
- **Acceptance criteria:** Freeze polling; type into an initially empty thread and immediately invoke system Back. It must show the discard decision, Keep editing must retain text/focus, and deliberate discard must leave. Clearing a draft permits ordinary Back. Cover app-bar/system Back, images, uncertain sends, and account loss with no network mutation from navigation.
- **Dependencies:** None beyond existing contracts; coordinate with this report's UI-001/UI-003.

### UI-003 — Vehicle edits and selected POD photos leave without discard protection

- **Priority:** P2: users lose entered vehicle information or a selected/captured delivery photo on accidental Back.
- **Confidence:** Confirmed source behavior; no native navigation observation was made.
- **Screen/state and source:** Dirty VehicleScreen or DeliveryTaskScreen with an unsubmitted photo. `lib/features/vehicle/presentation/vehicle_screen.dart:73`, `:86`; `components/vehicle_actions.dart:37`; `lib/features/delivery/presentation/components/delivery_task.dart:43`, `:74`; `components/delivery_photo_selection.dart:4`.
- **Evidence [SOURCE]:** Both screens use a Scaffold with automatic Back and no PopScope/UnsavedChangesGuard. Vehicle text controllers and selected document state are screen-local; `_hasLocalVehicleEdits` is used for refresh, not exit. Delivery owns `_selectedPhoto` locally and clears it on dispose. Registration and Account already wire `lib/shared/presentation/unsaved_changes_guard.dart`.
- **User impact:** Vehicle edits/OR/CR selections require re-entry; a captured POD may require another capture at the destination. This finding concerns unsent local work, not an assertion that committed uploads are undone.
- **Applicable rule:** Design guide, Familiar patterns and focused decisions / Components and interaction patterns: discard protection for unsaved work; existing shared guard/Material hierarchy.
- **Recommended change:** Apply the existing guard to these forms, detecting vehicle changes/selected documents and a selected unsent POD. Distinguish unsent selection from controller-owned uncertain writes; retain exact retries and clear private state immediately on authorization loss.
- **Acceptance criteria:** Back/system Back on each dirty field/file state offers Keep editing as the default focused action and deliberate Discard; untouched, reverted and confirmed-saved forms exit normally. Check picker/upload-in-progress navigation under the owning workflow without pretending cancellation reversed a write. Verify the eight phone/text/theme combinations and logout cleanup.
- **Dependencies:** Existing shared component; no new API or dependency. Review alongside this report's UI-002.

### UI-004 — OR/CR can only be inspected as cropped thumbnails

- **Priority:** P2: users cannot inspect a complete document before replacement or verify the saved evidence through the current View action.
- **Confidence:** Confirmed source restriction. The exact readability of a particular document was not measured.
- **Screen/state and source:** Vehicle local/current OR or CR preview. `lib/features/vehicle/presentation/components/vehicle_documents.dart:118`, `:180`, `:204`; `components/vehicle_actions.dart:222`.
- **Evidence [SOURCE]:** Both previews are fixed 124×92 `Image.memory` widgets with `BoxFit.cover`; portrait or differently proportioned documents are cropped. View current OR/CR only loads this inline thumbnail. No expansion, full-image dialog or zoom control exists in this flow.
- **User impact:** Key edges or document details can be omitted from the only available view, increasing uncertainty when choosing or replacing private evidence.
- **Applicable rule:** Design guide, essential context and clear upload feedback; Vehicle v2.5 independently authorized document preview; private-image upload boundary.
- **Recommended change:** Offer a labelled, feature-owned Material full-image preview using contain-fit and optional accessible zoom. Reuse existing presentation conventions without importing a feature-specific chat controller. Keep authenticated bytes in permitted memory and separate local selection from saved evidence.
- **Acceptance criteria:** A synthetic portrait/landscape OR/CR with labelled corners shows every edge in the expanded view. View/Close/Back/Escape are labelled and reachable at both phone sizes/scales/themes. Cover loading, unavailable/decode failure, retry and immediate private-image cleanup on account loss; no raw paths, public URLs or persistent evidence.
- **Dependencies:** Existing private document reads suffice; no backend addition.

### UI-005 — Vehicle cooldown leaves actions enabled and document reads bypass the wait

- **Priority:** P2: enabled controls either do nothing or repeat a throttled preview request, making recovery confusing and potentially prolonging throttling.
- **Confidence:** Confirmed source behavior for a positive Retry-After cooldown; no real-server throttle was exercised.
- **Screen/state and source:** Vehicle read/save/upload/private-preview after HTTP 429. `lib/features/vehicle/presentation/components/vehicle_details.dart:41`, `:231`; `components/vehicle_documents.dart:118`, `:139`; `controllers/vehicle_controller.dart:108`; `controllers/vehicle_controller_documents.dart:94`.
- **Evidence [SOURCE]:** Read/update/upload error handlers start `_retryTimer`. Load/update/upload guard `canRetryRateLimit`, but the visible Retry, Save and Upload controls check only busy state. They remain enabled when those methods reject the action. View current OR/CR also remains enabled, and `loadDocument` lacks both the cooldown guard and a loading/deduplication guard before calling `fetchDocument`; it can send another read during the wait.
- **User impact:** No reliable disabled-state cue tells a Courier when retry is available; repeated private-preview taps can send avoidable requests despite the server's waiting period.
- **Applicable rule:** API consumption rule for 429/Retry-After; design guide, disabled states and visible recovery feedback; Vehicle error/retry contract.
- **Recommended change:** Wire network-action enabled states to the existing cooldown and pending-read state, add the private-preview method guard, and display a clear waiting explanation. Keep local editing/discard available and avoid automatic request replay when the timer ends.
- **Acceptance criteria:** Inject 429 with a known wait for load, save, upload and preview. Tap/keyboard submissions and duplicate preview taps issue no additional request during cooldown; semantics identify disabled controls, text explains the wait, expiry reenables explicit retry without auto-request, and selected files/exact retry identity survive.
- **Dependencies:** Existing controller/API contract; no new package or quota assumption.

### UI-006 — Consent-screen Sign out skips the shared confirmation pattern

- **Priority:** P2: an immediate session-ending icon action differs from the Dashboard confirmation and the documented convention.
- **Confidence:** Confirmed source behavior; live logout was not submitted.
- **Screen/state and source:** AuthGate's required-policy screen with `showSignOutAction: true`. `lib/app/courier_app.dart:172`; `lib/features/policy/presentation/components/policy_consent.dart:89`, `:133`; contrast with `lib/features/dashboard/presentation/components/dashboard_navigation.dart:5`.
- **Evidence [SOURCE]:** Policy's icon calls `_signOut`, which directly invokes `authController.signOut`; no confirmation is shown. Dashboard's equivalent action uses the existing Sign out? Material dialog.
- **User impact:** An accidental tap ends the valid consent-pending session and loses current local confirmation choices, unlike the familiar behavior elsewhere.
- **Applicable rule:** Design guide, familiar Sign out behavior / Components and interaction patterns: confirmation for sign-out; consent must remain explicit and version-specific.
- **Recommended change:** Use the existing Sign out?/Cancel confirmation pattern from a responsibility-appropriate shared or feature-owned component. Keep sign-out available while consent is pending and preserve the existing failure feedback.
- **Acceptance criteria:** Opening Sign out does not send logout. Cancel/Back/Escape preserve session and policy choices; confirm sends once, then follows existing cleanup/failure behavior. Dialog actions remain reachable with logical focus in all eight combinations.
- **Dependencies:** Existing logout/consent contract; no approval or permission change.

## Prioritized implementation order

| Order | Findings to fix together | Proposed change | Acceptance/checks | Dependencies |
| --- | --- | --- | --- | --- |
| 1 | [This report: UI-001](flutter-ui-audit-2026-10-14.md#ui-001--chat-may-lose-reachable-controls-when-the-keyboard-reduces-available-height) | Reproduce keyboard/large-text constraints before deciding on chat layout changes | Keyboard, multiline text and long recovery message with production themes; then bounded layout if confirmed | Flutter widget/runtime execution; source suspicion alone does not authorize a fix |
| 2 | [This report: UI-002](flutter-ui-audit-2026-10-14.md#ui-002--fresh-chat-text-does-not-update-the-system-back-discard-guard), [UI-003](flutter-ui-audit-2026-10-14.md#ui-003--vehicle-edits-and-selected-pod-photos-leave-without-discard-protection) | Consistent dirty-state navigation protection | Immediate system/app-bar Back, Keep editing focus, confirmed discard, saved/reverted state, uncertain retry and auth cleanup | Existing guard; keep changes within chat/vehicle/POD workflows |
| 3 | [This report: UI-005](flutter-ui-audit-2026-10-14.md#ui-005--vehicle-cooldown-leaves-actions-enabled-and-document-reads-bypass-the-wait) | Visible cooldown and guarded/deduplicated private reads | Deterministic Retry-After, no extra calls, explicit retry after expiry | Existing controller contract |
| 4 | [This report: UI-004](flutter-ui-audit-2026-10-14.md#ui-004--orcr-can-only-be-inspected-as-cropped-thumbnails) | Full private/local document inspection | Complete-image corners, accessible View/Close, recoverable failure and scope cleanup | Existing private streams |
| 5 | [This report: UI-006](flutter-ui-audit-2026-10-14.md#ui-006--consent-screen-sign-out-skips-the-shared-confirmation-pattern) | Familiar sign-out confirmation on consent screen | Cancel preserves state; confirm sends once; large-text keyboard access | Existing logout/consent behavior |

## Contract gaps and handoff

- No missing endpoint blocks the confirmed recommendations: draft guards, authenticated OR/CR preview, cooldown presentation and sign-out confirmation use existing contracts. Chat keyboard remediation depends on rendered reproduction, not a new backend endpoint.
- The design guide still says dashboard aggregation is unavailable and failed-attempt submission unadopted; its historical scope text conflicts with newer owning contracts, current source and PROGRESS. The upload guide also retains older chat-adoption wording. Use the newer feature-specific adoption evidence for this review; no guide/contract was rewritten in audit mode. A future documentation sync should reconcile these summaries without treating it as UI verification.
- All twelve implemented Courier feature specs counted within 200–230 physical lines (Notifications 215, Support 204, others 230). Deferred Incident Reporting and Profit Dashboard drafts are 1,073 and 969 lines respectively and exceed the project rule. Their APIs/UI are not promoted by this report; read and reconcile those drafts completely before any work on them.
- Registration's separate OR/CR fields remain a coordinated future rollout; current registration retains `government_id`/`vehicle_registration`. The OR/CR preview recommendation applies only to the existing post-approval Vehicle feature and must not change registration fields.
- Keep normal final-mile acceptance atomic for the server's batch; hub confirmation and photo/intent acknowledgments remain pending until authoritative validation. No recommended UI change permits offline writes, fabricated tasks/totals, role/hub selection or treating a notification/scan as authority.
- Remaining coverage: resolve the test harness's loopback restriction in an environment that preserves source/dependency files, rerun existing checks, and observe all eight combinations and keyboard states for partial/unreviewed surfaces. Complete installed Android/TalkBack, localhost camera/file/private-media, real SMTP and deployed API acceptance separately with approved test data and authorization.
- This report records findings and verification limits. It makes no design exception, ships no UI changes and does not authorize fixes. An explicit improvement request should identify this report and the selected findings.
