# AISLEY Rider design context

Prepared 2026-10-28 using Google Stitch MCP. Design exploration only; no Flutter, API, dependency, asset, routing or theme implementation is authorized by these references.

## Authority and inspected baseline

- Flutter source: `a4f17bab5dd337c4a34f0a2d7f374cf12a91d003` on `main`; initial working tree clean. Documentation branch: `docs/aisley-rider-stitch-designs`.
- Latest adoption: platform `1858785e`, recorded in [Progress](../PROGRESS.md) on 2026-10-26. Deployed revision remains unknown.
- Shared UI authority: [Courier design guide](../design-courier.md), [project rules](../../AGENTS.md), and [feature rules](../features/courier/rules.md).
- Authentication retains separately adopted `4c3f504`; registration-email v1 / `27a6361`; password-code adoption 2026-10-14. Maps retain `51d9694`; failed attempts `4d8bfef`; media `28fc740`, with runtime evidence source `e6dc2cb4a7322dc3c5be649f467460c7e1114328`.
- Read the current progress, guide and relevant feature contracts; inspected Courier/Logistics domain and shared requirements/workspace/schema passages. Backend source was not accessed or changed.
- Older shared-guide/domain passages still describe atomic batch acceptance and mandatory transit before POD. The October parcel-decision/direct-delivery revisions and current Flutter source supersede those passages for this design brief. This task does not silently rewrite copied contracts.

## Current UI inspection

Inspected `lib/app/courier_theme.dart`, dashboard navigation/destinations, pickup list/detail composition, delivery composition/proof submission, chat inbox, linehaul list/confirmation and the existing screen inventory. Visually inspected the committed synthetic Home capture from the October 15 overhaul. That capture is historical evidence, not a fresh runtime screenshot of the October 26 application.

The current app uses Flutter Material 3, theme-derived light/dark colors, a four-destination shell, plain list rows, zero-elevation cards and Navigator detail routes. Work groups five existing workflows. Account groups profile, security, vehicle/documents, policies and support. Screenshots must preserve this structure, not introduce a browser dashboard.

## Objects, people and next actions

1. An approved Courier repeatedly checks assigned work on an Android phone, including poor connectivity and outdoor use.
2. A task is one parcel movement for one leg. First-mile and final-mile ownership remain independent.
3. Home answers which work needs attention; bounded previews never become complete workload totals.
4. Work answers where to open pickup, delivery, dispatch, linehaul or completed-history workflows.
5. An offered final-mile parcel has safe origin/area context and an explicit individual accept/reject decision.
6. An accepted Seller pickup requires identifier matching followed by an explicit pickup confirmation.
7. Accepted final-mile delivery permits photo POD and a linked Delivered intent without mandatory transit steps.
8. COD uses the server's payable total, with an unchecked exact-cash acknowledgment; merchandise price is not cash due.
9. Pending proof/intent review is separate from physical task state. Only the server-confirmed result is delivered.
10. Conversations are bilateral and task-scoped; eligibility controls counterpart access and sending.
11. Affiliation and hub are read-only identity context; profile/security/evidence remain separate workflows.
12. A linehaul driver reports departure/arrival; Logistics independently receives cargo and closes unloading.

Direction: familiar Material work lists, compact context and explicit step actions. The existing AISLEY task leg and Logistics review boundaries determine the visual hierarchy. No stylistic randomization was applied because the repository fixes the visual system. No photographs were sourced; parcel previews are illustrative diagrams, not real proof.

## Preserved tokens

| Role | Light | Dark |
| --- | --- | --- |
| Canvas | `#F7F7F8` | `#141416` |
| Surface | `#FFFFFF` | `#1C1C1E` |
| Main text | `#202024` | `#F3F3F5` |
| Secondary text | `#55555D` | `#C6C6CE` |
| Readable primary | `#C00065` | `#FF85BD` |
| Secondary | `#4C1268` | `#DCB0F1` |
| Error | `#B3261E` | `#FFB4AB` |

Brand accent is `#E6007A`. Use 4/8/12/16/24/32 spacing, 16px mobile margins, 12px cards, 10px buttons/fields and 48px minimum interactive targets. Stitch's Roboto Flex is a visual approximation to the existing platform typography, not approval to bundle a font or dependency. Existing purple brand tokens take precedence over the taste skill's generic palette preference.

Root navigation labels remain **Home**, **Work**, **Task messages**, **Account**. Details, forms, private media, maps and cameras use Back above the shell. Work feature roots retain Work navigation. Text/status/context must wrap at 2× scaling; screenshots alone cannot establish that behavior.

## Screen contract references

| Design group | Owning contract | Boundary |
| --- | --- | --- |
| Home / Work | [Dashboard v2.8](../features/courier/dashboard/specs.md) | Read-only v2, independent freshness, v1 fallback; no fake totals |
| Offers / dispatch | [Acceptance v2](../features/courier/accept-delivery-requests/specs.md) | Per-parcel decisions and current membership; no normal Accept all |
| Pickup / scan / route | [Pickup v2.12](../features/courier/pick-up-order/specs.md) | First-mile scan/manual match then confirm; hub handoff has no identifier |
| Delivery details | [Delivery v1.10](../features/courier/delivery-order/specs.md) | Accepted-task direct-delivery v2; routes are advisory |
| Photo / review | [POD v1.10](../features/courier/proof-of-delivery/specs.md), [Completion v1.10](../features/courier/complete-delivery/specs.md) | Private photo then matching intent; HTTP 202 is not delivered |
| Messages / thread | [Messaging v2.5](../features/courier/chat-messaging/specs.md) | No arbitrary contacts, presence, calls or offline sends |
| Account | [Account v2.5](../features/courier/account-management/specs.md) | Read-only affiliation/legal fields; allow-listed profile fields only |
| Sign in / registration | [Auth v2.7](../features/courier/auth/spec.md), [registration-email v1](../registration-email.md) | Six steps, email first; pending approval grants no operational access |
| History | [History v1.5](../features/courier/delivery-history/specs.md) | Exact reference search; only server-confirmed final-mile deliveries |
| Notifications | [Notifications v1.2](../features/courier/notification/specs.md) | Explicit read marking; links reauthorize and do not mutate work |
| Linehaul | [Linehaul v1](../linehaul-trips.md) | Source release gates departure; arrival does not receive cargo |
| Account support entry | [Support v1.1](../features/courier/support-tickets/spec.md) | Separate requester tickets, no attachments or task-state authority |

## State and privacy handoff

Keep loading, confirmed empty, unavailable/scaffold, forbidden, partial, stale, offline, timeout, conflict, validation, throttled, uncertain submission and success distinct. Retain permitted stale content with freshness and recovery; never submit offline. Honor Retry-After, refresh conflicts and preserve exact uncertain attempts without automatic mutation replay.

Synthetic names, references, times and PHP 115.00 illustrate separate lifecycle snapshots, not live API data. A reference appearing as offered on one screen and accepted on another denotes different workflow states. No actual Courier data, bearer tokens, environment values, private media or customer street/contact information was sent to Stitch. No local `.env` was read or copied.

The generated Stitch design system is a tool artifact, not an authority: its initial slide-to-complete suggestion, tinted default palette, general AAA claims and any invented navigation/metadata must not be adopted. Familiar explicit tap buttons, repository tokens and documented confirmations win. Refinement prompts correct the principal screen deviations; remaining differences are documented in the review.

## Verification limits

This is source/contract inspection plus static screenshot review. No Flutter changes, hot reload, application tests/builds, live API calls, authenticated browser testing, installed-device checks, text-scaling interaction or screen-reader acceptance were performed. No executable Stitch HTML is installed or stored as a separate frontend; only remote reference IDs are retained.
