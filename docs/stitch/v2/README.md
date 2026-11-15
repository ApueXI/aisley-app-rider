# AISLEY Rider V2 — Stitch design references

Prepared 2026-11-12. **Design references only; Flutter frontend unchanged.**

[Open AISLEY Rider V2 in Google Stitch](https://stitch.withgoogle.com/projects/8494920215314554832) · Private project ID `8494920215314554832`

32 retrieved PNGs cover 16 screen/state families: the initial set plus one refinement of every screen. Stitch names refinement screens `V3`; they still belong to the AISLEY Rider V2 project. The [earlier exploration](../README.md) remains preserved.

Read [design context](CONTEXT.md) and [review findings](REVIEW.md). Most refined images improve the initial drafts; Work typography, pending-review copy and consent content still require correction. These are not approved implementation designs. A final attempt to regenerate those screens and add thread/support/dark appearance references hit a transport error; no additional screenshots are claimed.

## Screen index

Each ID below identifies its retrieved refinement. Original IDs, screenshot-file IDs and HTML references remain in [provenance](provenance.json). No HTML/frontend code was downloaded into the application.

| Screen | Refined PNG | Initial PNG | Refined screen ID |
| --- | --- | --- | --- |
| Task details | [PNG](screenshots/v3-task-details.png) | [PNG](screenshots/v2-task-details.png) | `ea8dc129cf8f4de898c6d5ccba645327` |
| Home | [PNG](screenshots/v3-home.png) | [PNG](screenshots/v2-home.png) | `867ede9097484d37901c1dc03fc5714b` |
| Pickup scan review | [PNG](screenshots/v3-pickup-scan-review.png) | [PNG](screenshots/v2-pickup-scan-review.png) | `b845f6d3eaf2443d8d2b3c6fb5efa4e8` |
| Work | [PNG](screenshots/v3-work.png) | [PNG](screenshots/v2-work.png) | `a2e9bdcc6dbf4d1d8ceb2d3ab7d7cca9` |
| Delivery photo and cash | [PNG](screenshots/v3-delivery-photo-and-cash.png) | [PNG](screenshots/v2-delivery-photo-and-cash.png) | `0dcc3688836945938fafdd17e1a15928` |
| Task messages | [PNG](screenshots/v3-task-messages.png) | [PNG](screenshots/v2-task-messages.png) | `a830464baad94e4d91481b6518df5797` |
| Registration OTP | [PNG](screenshots/v3-registration-otp.png) | [PNG](screenshots/v2-registration-otp.png) | `3eefebc580494fb885809f69bef7c965` |
| Sign in | [PNG](screenshots/v3-sign-in.png) | [PNG](screenshots/v2-sign-in.png) | `c3413f2d215d4902a486457783e104f5` |
| Account | [PNG](screenshots/v3-account.png) | [PNG](screenshots/v2-account.png) | `0f35a0c872c94b54952ce13cae2cf861` |
| Delivery history | [PNG](screenshots/v3-delivery-history.png) | [PNG](screenshots/v2-delivery-history.png) | `f35201e0917c4b05b77239c774b2572e` |
| Final-mile batches | [PNG](screenshots/v3-final-mile-batches.png) | [PNG](screenshots/v2-final-mile-batches.png) | `646b20f1476c45f2882fff1c24d4cfe8` |
| Notifications | [PNG](screenshots/v3-notifications.png) | [PNG](screenshots/v2-notifications.png) | `98dfb5bd58794a17a014b3f643e884a5` |
| Pickup route unavailable | [PNG](screenshots/v3-pickup-route-unavailable.png) | [PNG](screenshots/v2-pickup-route-unavailable.png) | `7ee8e5b57abd46e995b9a58e5b2b9b1d` |
| Linehaul arrival reported | [PNG](screenshots/v3-linehaul-arrival-reported.png) | [PNG](screenshots/v2-linehaul-arrival-reported.png) | `40e2e67affb8464ba323997afd06972c` |
| Delivery awaiting review | [PNG](screenshots/v3-delivery-awaiting-review.png) | [PNG](screenshots/v2-delivery-awaiting-review.png) | `7278e291fd16413e9262cbd35eaf7004` |
| Policies consent | [PNG](screenshots/v3-policies-consent.png) | [PNG](screenshots/v2-policies-consent.png) | `d4ea9b9bf1a2470ca862904025b2e2f1` |

## Browse and verify

- Refined contact sheets: [Home/Work/tasks/pickup](refined-sheet-1.png), [delivery/messages/account/sign-in](refined-sheet-2.png), [OTP/batches/history/notifications](refined-sheet-3.png), [route/linehaul/review/consent](refined-sheet-4.png).
- Initial auxiliary sheets: [1](auxiliary-sheet-1.png), [2](auxiliary-sheet-2.png). Sheets are reduced previews; original PNGs retain complete export dimensions.
- [Export inventory](exports.json): local paths, dimensions and SHA-256 hashes for all 32 unique screenshots.
- [Provenance](provenance.json): project/session/screen/file IDs, exact prompts, tool descriptions/suggestions, failed requests and retrieval limits.
- [Generated design system](generated-design-system.json): original tool artifact with unsupported examples; CONTEXT.md and repository theme remain authoritative.
- [Verification record](VALIDATION.md): documentation/export checks and limits.

The intended phone viewport is 390×844 logical pixels. Actual exports are 780px wide with variable full-content heights; they are synthetic images, not installed-device captures. No live API, Flutter runtime, interactive prototype, accessibility certification or installed APK acceptance is established.
