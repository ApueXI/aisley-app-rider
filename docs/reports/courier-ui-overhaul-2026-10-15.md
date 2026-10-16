# AISLEY Courier UI overhaul — 2026-10-15

## Implementation and authority

Implementation commit: `2049809` (`feat: overhaul AISLEY Courier navigation and workflows`). Verification evidence is committed separately.

Implemented the approved whole-project redesign on `feature/courier-ui-overhaul`, created from `feature/courier-ui-review-skill` before application edits. The original audit/progress changes were kept separate and subsequently committed as `bef3374` (audit only); application baseline remains `ee62d69`. Historical audit evidence and progress are preserved, with remediation appended below the original audit.

Latest recorded backend: `27a6361`; registration-email v1 (2026-10-14). Password-code requirements remain locally adopted on 2026-10-14. Auth `4c3f504`, operations `d7df220`, maps `51d9694`, failed attempts `4d8bfef`, and media `28fc740` remain separately adopted feature baselines. The original [contract map](flutter-ui-audit-2026-10-14.md#contract-map) identifies each owning specification. Deployed API revision remains unidentified. This change adds no endpoint, DTO, package, role, permission, transition, cache persistence or backend implementation.

| Area | Result |
| --- | --- |
| Theme and branding | Neutral light/dark surfaces, accessible existing magenta, restrained purple, 12px cards, 10px fields/buttons, shared spacing and minimum 48px controls. System typography is retained. Startup, application titles and Android/web metadata use AISLEY Courier. |
| Navigation | Home, Work, Task messages and Account persist on destination roots. Work groups Pickup orders, Delivery work, Final-mile batches and Delivery history. Account groups profile, security, vehicle/documents, policies, support and confirmed sign-out. Navigator details/forms/cameras/maps open above the shell. |
| State and visibility | Visited roots retain scroll and filters in memory. System Back from another tab returns Home; detail Back returns to its owner. Route/lifecycle visibility stops hidden notification/chat timers. AuthGate closes private routes on session loss; existing session callbacks clear account data. |
| Home | Compact Courier/affiliation context, active work before available work, pickup/delivery shortcuts and Notifications. V2 keeps independent section freshness/errors; default-v1 fallback preserves separate bounded source previews. No preview count is presented as a complete workload total. |
| Registration | Email verification → personal details → address → Logistics/vehicle → evidence → review/password. Back/Continue preserve drafts; validation reveals and focuses its owning step. Expiry returns to email, preserves permitted entries/files and clears passwords. Existing uncertain-submission and cancellation rules remain. |
| Operations | Task rows present reference, leg, status, authorized location and next prerequisite. Details place essential context and the current action ahead of secondary messaging. Acceptance, custody validation, movement, photo submission, explicit COD acknowledgment, completion intent and Logistics review remain distinct. |
| Communication/support | Flat lists, contextual status, timestamps, existing loading/empty/error states and reachable composers. Thread context scrolls; recovery/composition stays bounded with the keyboard open. Existing private media behavior and frozen retry identities remain. |
| Account/evidence | Profile and security open as separate workflows. Saved profile evidence remains distinct from a selection. Vehicle changes and unsent POD selections receive discard protection. Saved/selected OR/CR open a complete contain-fit image with Zoom/Fit/Close and Escape. |
| Maps | Surrounding spacing follows the theme. Authorized geometry, numbered stops, controls, attribution, scope boundaries and accessible list fallback remain intact. |
| Modularity | Shell content/destinations, six registration steps, thread body, policy current-version card, task rows, preview and confirmation widgets have focused responsibilities. Existing repositories/controllers and Navigator architecture remain. |

The [design guide](../design-courier.md) records approved navigation/component conventions and the public design references. Familiar Material lists, fields, dialogs, Back and labels are reused. Each task/form step keeps its prominent next action and secondary alternatives; operational and policy confirmations remain explicit.

## Audit revalidation

All UI-001–UI-006 findings were still applicable. UI-001 was suspected in the audit and is now reproduced in a deterministic widget harness, before claiming resolution.

| Finding | Implementation and evidence | Verification scope |
| --- | --- | --- |
| UI-001 | Old thread composition overflowed by 1,140px at 320×640, 2× text, 280px keyboard inset, multiline draft and long recovery text. [Preserved excerpt](courier-ui-overhaul/chat-keyboard-reproduction.txt). New `ChatThreadBody` scrolls context and bounds recovery/composition. | Eight keyboard layout cases and send-target access in `chat_layout_test.dart`; no render overflow. Actual device keyboard and TalkBack remain pending. |
| UI-002 | Text changes immediately update the shared Back guard. Unresolved sends retain the existing Leave conversation decision and exact request. | Immediate system Back → Keep editing retains text before another poll; existing send/media retry tests pass. |
| UI-003 | Shared discard guard covers vehicle edits/selected documents and unsent delivery photos; busy operations block user exit and session loss clears private state. | Eight vehicle phone/theme/text cases; dedicated POD Keep editing/Discard test proves no upload/completion occurs on navigation. |
| UI-004 | Saved and selected OR/CR open authorized in-memory bytes in a full contain-fit viewer with labelled zoom, Fit, Close and Escape. Closing the owning screen clears previews; late reads cannot restore them. | Eight vehicle preview cases; synthetic portrait/landscape pixel checks show all four corners, authorization removal hides the image, Escape returns to the owner. |
| UI-005 | Cooldown disables network controls and guards direct load/save/upload/preview and exact retries. Preview reads deduplicate; expiry enables explicit retry without replay. | Four operation throttle cases, duplicate/obsolete-read tests and existing vehicle conflict/validation/reconciliation regressions. |
| UI-006 | Policy sign-out uses the shared confirmed-sign-out dialog, with Cancel focused and duplicate prompts prevented. | Eight phone/theme/text cases; Cancel performs no logout, explicit confirmation performs one. Existing consent version/checkbox behavior passes. |

## Local verification

- Final complete suite: **979 tests pass** (`flutter test --no-pub --concurrency=2`, 4m08s), including the paused-start polling regression. Earlier integration passes were followed by a final rerun after all UI refinements.
- Analyzer: **no issues found** (`flutter analyze --no-pub`, 7.9s). Changed Dart files are formatted. Flutter 3.47.2 / Dart 3.13.2 on Linux x64 were used.
- Synthetic capture: eight after screenshots plus four original Home/sign-in screenshots, 390×844, production Roboto/Material fonts, light/dark. Captures use only synthetic names, references, addresses and evidence; they are review artifacts rather than golden assertions.
- Automated coverage includes 320×640 and 390×844, 1×/2× text, both themes, an 1100×800 wider shell, keyboard insets, focus, Android/iOS touch targets, labels and contrast. Existing suites cover loading, empty, unavailable, stale, partial, forbidden, recoverable error and success states.
- Contract regressions cover authorization, uploads, conflict/validation, Retry-After, uncertain mutations and retained retry keys, secure-storage failures and logout. Notification targets revalidate owning work; tests prove navigation does not mutate it.
- No Courier specification changed. Twelve adopted Courier specs retain 200–230 physical lines. Two pre-existing unadopted incident/profit specs exceed that range and were left outside this overhaul. Vehicle/shared-policy contracts retain their adopted copies; no API synchronization was required.
- Git whitespace, historical audit/progress prefixes, dependency/lock preservation and scoped diff were checked. Android release and web builds pass, with artifacts recorded below.

## Build artifacts

| Command | Result | Local artifact |
| --- | --- | --- |
| `flutter build apk --release --no-pub` | Pass, 90.1s final incremental build; 109.1MB. Existing SDK XML-reader warning is informational; assembly succeeded. | [Release APK](../../build/app/outputs/flutter-apk/app-release.apk) |
| `flutter build web --no-pub --no-wasm-dry-run` | Pass, 75.9s final JavaScript build. An earlier standard web build also passed its WebAssembly dry run. | `build/web` |
| Synthetic screenshot command below | Eight after capture checks pass; four readable before captures retained. | [Screen comparisons](#synthetic-screen-comparisons) |

Artifacts use the existing build configuration. A successful local build does not certify a deployed API or release environment.

- APK SHA-256: `c5acd29c0d8109860370b10268cbdd01fc574df4667c0868d4ee295d6e5418d4`.
- `build/web/main.dart.js` SHA-256: `e22877e41d91372382605e4d5e1325f7d2980f8f2a4179765f2b6a3f75f6ab10`.

## Synthetic screen comparisons

| Screen | Before (original app source) | After |
| --- | --- | --- |
| Home, light | [Before](courier-ui-overhaul/screenshots/before-home-light.png) | [After](courier-ui-overhaul/screenshots/after-home-light.png) |
| Home, dark | [Before](courier-ui-overhaul/screenshots/before-home-dark.png) | [After](courier-ui-overhaul/screenshots/after-home-dark.png) |
| Sign-in, light | [Before](courier-ui-overhaul/screenshots/before-sign-in-light.png) | [After](courier-ui-overhaul/screenshots/after-sign-in-light.png) |
| Sign-in, dark | [Before](courier-ui-overhaul/screenshots/before-sign-in-dark.png) | [After](courier-ui-overhaul/screenshots/after-sign-in-dark.png) |
| Email verification | — | [Light](courier-ui-overhaul/screenshots/after-registration-email-light.png), [dark](courier-ui-overhaul/screenshots/after-registration-email-dark.png) |
| Registration review/password | — | [Light](courier-ui-overhaul/screenshots/after-registration-review-light.png), [dark](courier-ui-overhaul/screenshots/after-registration-review-dark.png) |

Before captures used temporary copies of the original theme, sign-in and dashboard composition from the audit baseline; those source copies were removed. After Home also supplies synthetic affiliation and operational controllers to expose the new shortcuts/Notifications access. The registration review capture shows a scrolled form. Representative screenshots were visually inspected for readable typography and clear action hierarchy.

Reproduce after captures using the existing SDK fonts:

```sh
flutter test --no-pub test/manual/courier_overhaul_screenshots_test.dart \
  --dart-define=SNAPSHOT_PHASE=after \
  --dart-define=FLUTTER_FONT_DIR=/path/to/flutter/bin/cache/artifacts/material_fonts
```

## Acceptance still separate

| Acceptance | Status |
| --- | --- |
| Installed Android release: real Back, keyboard, camera permissions/capture, file selection and uploads | Pending; fake platforms/widget tests and a build cannot establish hardware acceptance. |
| TalkBack/VoiceOver and physical keyboard focus/reading order | Pending; automated semantics, contrast and target checks pass to their stated scope. |
| Same-app localhost browser camera/upload and private media runtime | Pending; web compilation and synthetic widget captures do not establish browser permissions or transport. |
| Authenticated deployed API: registration/email, approval, work/maps, messaging, evidence/COD/Logistics review and logout | Pending; no live account, private evidence or operational mutation was used. |

No earnings, availability toggle, background tracking, linehaul/recovery destination or unadopted feature was introduced.
