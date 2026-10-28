# AISLEY Rider — Stitch references

[Open AISLEY Rider in Google Stitch](https://stitch.withgoogle.com/projects/13625567050207019759).

Project ID: `13625567050207019759` · Private · Created 2026-10-28 using Google Stitch MCP.

Mobile design exploration for the existing Flutter application. **No frontend implementation has changed.** These drafts require the corrections in [REVIEW.md](REVIEW.md) before adoption. Stitch edit confirmations do not prove that exported screenshots refreshed.

- [Design context, inspected sources and contract versions](CONTEXT.md)
- [Static review, requested corrections and remaining gaps](REVIEW.md)
- [Screen/file IDs, prompts and export references](manifest.json)
- [Core refinement request and returned edit events](refinements.json)
- [Generated design-system artifact](stitch-design-system.json) — repository conventions take precedence
- [Stitch generation descriptions and optional suggestions](GENERATION-NOTES.md)
- [Account, messaging, authentication and auxiliary corrections](secondary-refinements.json)

The intended brief is a 390×844 logical-pixel Android phone. Stitch exports are 780px wide with variable full-content heights, recorded in the manifest; they are not installed-device captures. All displayed identity, task and amount examples are synthetic. The set represents workflow states at different moments rather than a simultaneous live workload.

## Screen index

The generated index below links to local PNGs and records retrievable Stitch screen IDs. IDs are references, not API task identifiers. Remote HTML file IDs are retained for design provenance only; no executable HTML was installed in this repository.

| Screen | PNG reference | Stitch screen ID |
| --- | --- | --- |
| 01-home | [AISLEY Rider - Home](screenshots/01-home.png) | `415b5cc6007b40d0b555cb52ebbe61c2` |
| 02-work | [AISLEY Rider - Work](screenshots/02-work.png) | `bda0d9bd5cce49f2b5218844f9a8e4e9` |
| 03-task-details | [AISLEY Rider - Task Details (ORD-DEMO-1042)](screenshots/03-task-details.png) | `6bcefbe389b442d9a9fdeea159977b06` |
| 04-pickup | [AISLEY Rider - Pickup Fulfillment (ORD-DEMO-1043)](screenshots/04-pickup.png) | `7e55ace5e3634cd0b9c375694d2e18bb` |
| 05-delivery | [AISLEY Rider - Delivery Fulfillment (ORD-DEMO-1042)](screenshots/05-delivery.png) | `4b1433fa32bb4742bd561241fead4f07` |
| 06-messages | [AISLEY Rider - Task Messages](screenshots/06-messages.png) | `bf6b863f21de461989f1e1f181e5cebb` |
| 07-thread | [AISLEY Rider - Message Logistics (ORD-DEMO-1042)](screenshots/07-thread.png) | `079a5a406bc8433a89af64c60861639f` |
| 08-account | [AISLEY Rider - Account](screenshots/08-account.png) | `99f55660e4004e42adf366ef568496b5` |
| 09-sign-in | [AISLEY Rider - Sign in](screenshots/09-sign-in.png) | `03a43be4cbf64194991a9ccb17e54db6` |
| 10-registration | [AISLEY Rider - Email verification (Step 1 of 6)](screenshots/10-registration.png) | `ded822dfed954d67adf7a98f0755ec34` |
| 11-batches | [AISLEY Rider - Final-mile batches (DSP-DEMO-24)](screenshots/11-batches.png) | `9f19cfc71ec44fb88a2539d38b0a7a94` |
| 12-history | [AISLEY Rider - Delivery history](screenshots/12-history.png) | `dd30b8490bae408ebd55d370ef1c55d7` |
| 13-notifications | [AISLEY Rider - Notifications](screenshots/13-notifications.png) | `07e0411e74a64f159c8a18d13d7ae260` |
| 14-route-fallback | [AISLEY Rider - Pickup route (SCH-DEMO-12)](screenshots/14-route-fallback.png) | `348ac9d2e88e4e91806b7741e1676fa3` |
| 15-linehaul | [AISLEY Rider - Linehaul jobs](screenshots/15-linehaul.png) | `15d7e65a7f9b4681b4f53e0b45f0167d` |
| 16-review | [AISLEY Rider - Delivery review (ORD-DEMO-1042)](screenshots/16-review.png) | `153611a107894e468be9d4812c90d698` |

## Refined exports

Seven additional exports were retrieved after auxiliary refinement. Account, notifications, sign-in, thread, linehaul and route fallback show visible corrections; the refined registration export is rejected because its verification form is missing. Use the review status, not the tool narrative, to choose references.

| Refined screen | PNG reference | Stitch screen ID |
| --- | --- | --- |
| 08-account-refined | [reviewed-static-draft](screenshots/08-account-refined.png) | `d3ca2fbff9ad4cbf80c9f47c30e1c621` |
| 13-notifications-refined | [reviewed-static-draft](screenshots/13-notifications-refined.png) | `82f3f9fa38e041898d261d6ca05ac495` |
| 10-registration-refined | [rejected-missing-verification-form](screenshots/10-registration-refined.png) | `c11bcb7ce3a8427d9808d35c6ba0e13f` |
| 09-sign-in-refined | [reviewed-static-draft](screenshots/09-sign-in-refined.png) | `18b10e7a2b484041a851e946083a2985` |
| 07-thread-refined | [reviewed-static-draft](screenshots/07-thread-refined.png) | `944ae32fd0674318a524d153cb93b290` |
| 15-linehaul-refined | [reviewed-static-draft](screenshots/15-linehaul-refined.png) | `0d506afb36fe4afd89f53523ef6e8ed9` |
| 14-route-fallback-refined | [reviewed-static-draft](screenshots/14-route-fallback-refined.png) | `5b21c90a121a4e7f9a4fd2e05c90fdff` |

[Refined export metadata and hashes](refined-exports.json).

## Retrieval and review

Use Stitch `get_screen` with `projects/13625567050207019759/screens/{screen-id}`. Download its screenshot using Stitch `download_file` and the returned `screenshot.name`; direct download URLs may require credentials and are not durable artifacts. Local images preserve the bytes retrieved during this task.

At final retrieval, Stitch `list_screens` exposed four core screens while the other generated IDs remained individually retrievable through `get_screen`. The manifest and local PNGs preserve all 16 references; complete canvas/list visibility is not verified. Use individual resource IDs when the project listing omits a reference.

Read `CONTEXT.md` and `REVIEW.md` alongside any image. Initial generated copy includes unapproved capabilities and presentation deviations. Corrections belong in Stitch until Flutter implementation is explicitly requested. Existing code, shared guides and current adopted server contracts remain authoritative.

The source inspection and historical baseline screenshot are distinguished from generated imagery in `CONTEXT.md`. No fresh Flutter runtime, release build, live API, device, keyboard, large-text or assistive-technology acceptance was performed for this documentation-only task.
