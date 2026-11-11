# AISLEY Rider V2 design context

Prepared 2026-11-12 using Google Stitch MCP. Static design exploration only. No Flutter implementation, frontend assets, packages, API changes or theme adoption are authorized by these references.

## Project and baseline

- Private project: [AISLEY Rider V2](https://stitch.withgoogle.com/projects/8494920215314554832), ID `8494920215314554832`.
- Previous [AISLEY Rider references](../README.md) and project `13625567050207019759` remain preserved.
- Flutter inspected at `dc53bc05fe093bb81c19efee24898ea43cf99d99`, initially clean on `feature/map-layering-hidden-coordinates`. Documentation branch: `docs/aisley-rider-v2-stitch`.
- Latest progress: 2026-11-11 map viewport/stacking containment. Platform adoption `1858785e`; Auth `4c3f504`; registration implementation `27a6361`, later client contract `automatic-registration-v2` (2026-11-04); combined consent `policy-consent-batch-v1`, backend `6693b0cc9172981fa2370e3cc4e1fe6e9aec7f93`; maps `51d9694`; failed attempts `4d8bfef`; media `28fc740` with historical runtime source `e6dc2cb4a7322dc3c5be649f467460c7e1114328`. Deployed revision remains unknown. No backend checkout was accessed.

## Existing UI inspection

Read [project rules](../../../AGENTS.md), [progress](../../PROGRESS.md), [design guide](../../design-courier.md), [feature rules](../../features/courier/rules.md) and the owning feature specs. Inspected Material theme, dashboard shell/destinations, pickup verification, delivery photo/intent composition, sign-in, registration step navigation, appearance dialog and linehaul detail source. Reviewed the committed [synthetic Home screenshot](../../reports/courier-ui-overhaul/screenshots/after-home-light.png). It is historical October 15 evidence, not a fresh runtime capture of this checkout. No application was launched, authenticated or connected to real private data.

Current structure: four persistent destinations; Navigator detail/form/camera/map routes; Work groups five workflows; Account groups profile/security/vehicle/appearance/policies/support/sign-out. The theme uses Material 3, flat neutral surfaces, magenta primary, 10px controls, 12px cards and padded 48px targets. Retain these familiar interactions. Roboto Flex in Stitch is a visual stand-in; Flutter uses its existing platform TextTheme without a newly approved font package.

## Direction and screen questions

The direction is an existing-brand refinement: neutral Courier work surfaces, compact parcel context, one prominent next action. No random style draw is used because the repository fixes the palette and Material interaction system. The product-specific element is the parcel reference plus independent first/final-mile label, carried through tasks, proof and messages.

1. Home: which authorized work needs attention? Show bounded active before available previews and independent freshness; no workload totals.
2. Work: which existing workflow should open? Five plain rows, no operational mutation.
3. Task details: is this parcel offer appropriate? Area-safe context and explicit individual decision.
4. Pickup: which code was captured? Scan-only read-only candidate, then explicit physical pickup confirmation through the server.
5. Delivery: is photo proof ready and was the exact authorized cash amount collected? Unchecked cash consent and Delivered intent, followed by review.
6. Task messages: which task/counterparty needs a reply? Task-linked rows; no shifts, presence, ETA or general directory.
7. Account: which account setting is needed? Grouped existing flows and read-only affiliation.
8. Sign-in/registration: can access be restored or an application submitted? Details first, dedicated OTP, automatic initial submission, Logistics approval.
9. Batches/history: which parcel decision or completed reference is needed? Independent members and exact-reference history.
10. Notifications/routes/linehaul/review: what is known and what can safely happen next? Distinguish read state, missing route data, driver arrival and Logistics validation.
11. Policies: which current documents need explicit consent? Both documents remain readable with separate unchecked selections and one Accept.

All names, references, dates, amounts and snippets are illustrative. `ORD-DEMO-1042/1043`, Mika Santos, `mika@example.invalid`, Example Logistics and PHP 115.00 are design data, not API facts. They confer no task ownership. No real uploaded proof, credentials, QR payload, phone number or full address was sent to Stitch. Preview panels are placeholders for future authorized local evidence, not production proof.

## Contract precedence and known conflicts

- The guide retains older email-first registration wording. [Registration email contract](../../registration-email.md), Auth spec and inspected step navigation establish details → OTP → automatic initial submission. Never activate an account merely from verification.
- Older guide/manual pickup wording and backend compatibility routes do not restore manual Flutter input. Pick-up spec v2.13 and October 29 adoption establish scan-only first-mile capture. Code128 capture does not establish a separate server match success before confirmation; only the QR path has its explicit match read.
- Older domain descriptions of all-at-once batch acceptance and mandatory transit are superseded for these references by `courier-final-mile-parcel-decisions-v2` and `courier-direct-delivery-v2`. Each parcel decision remains independent; accepted-task photo/intent does not require fabricated intermediate milestones.
- Notification destinations remain allow-listed; linehaul job availability does not itself prove notification-to-linehaul navigation adoption.
- Company-created Courier email change is mentioned in registration context without a matching adopted mobile capability. No email-change design is introduced.
- The generated Stitch design system includes unauthorized examples (earnings, payouts, shifts, slide actions, bulk acceptance). A corrective `update_design_system` request returned `Request contains an invalid argument.` Its requested replacement is saved in [provenance](provenance.json) and repeated explicitly in later prompts. Autogenerated notes never override the repository guide.

## Source map

Owning contracts: [Dashboard](../../features/courier/dashboard/specs.md), [acceptance](../../features/courier/accept-delivery-requests/specs.md), [pickup](../../features/courier/pick-up-order/specs.md), [delivery](../../features/courier/delivery-order/specs.md), [proof](../../features/courier/proof-of-delivery/specs.md), [completion](../../features/courier/complete-delivery/specs.md), [chat](../../features/courier/chat-messaging/specs.md), [Account](../../features/courier/account-management/specs.md), [Auth](../../features/courier/auth/spec.md), [history](../../features/courier/delivery-history/specs.md), [notifications](../../features/courier/notification/specs.md), [support](../../features/courier/support-tickets/spec.md), [linehaul](../../linehaul-trips.md), [upload transport](../../flutter-file-uploads.md). Shared Courier/Logistics domains and Courier passages of requirements/workspace/schema establish role boundaries. No copied contracts are revised by this work.

## Review boundary

Static PNG inspection checks visible labels, task context, authority and action hierarchy. It does not prove tap behavior, font loading, contrast, 320px or 2× text layouts, keyboard/focus, screen readers, Android/web camera/file transport or deployed API behavior. No frontend browser inspector or Flutter analyze/test/build was run for design-only exports. Future implementation must retain authorized contact/address context, validation, discard guards, scope cleanup, retry identities and accessible scroll behavior even where a representative screenshot omits them.
