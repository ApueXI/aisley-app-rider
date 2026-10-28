# Static reference review — 2026-10-28

These are exploration references, not approved replacements for the current Flutter UI. The repository design guide and adopted feature contracts remain authoritative.

## What the direction preserves

- Four primary destinations, Work's five workflow entries, Account's grouped destinations and Back on detail routes.
- Visible task identity, independent legs, bounded Home previews and a recoverable stale section.
- Explicit parcel acceptance, first-mile identifier matching followed by confirmation, and unchecked COD acknowledgment.
- Separate task messages, notification inbox and support-ticket entry points.
- Pending Logistics review distinguished from delivered; linehaul arrival distinguished from cargo receipt.

## Corrections requested in Stitch

The five core-screen refinement requests restore **Task messages**, compact Home and Work, remove technical banners/invented zones and handling metadata, use neutral canvas colors, place task references on their own lines, and restore the exact **Delivered** label with disabled styling until the cash prerequisite is satisfied. See `refinements.json` for the actual request and returned edit events.

The edit tool returns DOM-operation events and a prose confirmation. The re-downloaded Home screenshot is byte-identical to the original export. Therefore the local PNG exports are the retrievable generated references, not proof that the requested refinements were rendered. Keep the original export IDs and inspect the current Stitch canvas before future implementation.

A second correction request targets Account, notifications, registration, sign-in, the uncertain-message thread, route fallback and linehaul. Its exact request and response are retained in `secondary-refinements.json`. Unlike the first edit, this response includes seven new screen resources. All seven PNGs were downloaded and visually inspected: Account, notifications, sign-in, thread, linehaul and route fallback show the requested principal corrections. The registration variant is rejected because the verification form disappeared, despite the tool's prose claiming a complete form. Keep the initial registration reference with its documented corrections; neither registration image is approved for adoption. IDs, hashes and review disposition are in `refined-exports.json`.

## Remaining review gates

| Priority | Observation in generated references | Required decision before Flutter adoption |
| --- | --- | --- |
| High | Account introduces app PIN/biometrics, license verification, incident language, a synthetic Courier ID and protocol version | Use existing labels: Profile; Security / Change your password; Vehicle and documents / Official receipt and registration; Policies / Current versions and consent history; Support tickets / Contact platform support. Remove invented capabilities/IDs/protocol text. |
| High | Initial delivery export says Mark as Delivered and includes unsupported route/zone/capture metadata | Use Delivered intent, exact cash due, unchecked acknowledgment and pending Logistics review; remove invented facts. Refinement requested, rendered correction unverified. |
| High | Initial pickup export includes invented handling/zone/timestamp data and a barcode-like decoration | Show only actual authorized projection and matched candidate; no synthetic barcode is production identity. Refinement requested. |
| High | Stitch's initial design system suggests slide-to-complete and implies broad accessibility certification | Ordinary labelled Material tap controls and documented confirmations only; no new gesture or certification. |
| High | Notifications generation narrative adds Mark all as read despite the requested explicit per-notification read boundary | Remove bulk-read controls; only the documented detail action may mark one notification read. |
| High | Registration export says verification confirms eligibility/activates a profile and displays a sample numeric code | Email verification proves inbox access only; it creates no account, approval or session. Use an empty code field and remove unsupported pre-login support actions. |
| High | Sign-in export implies a password assigned by Logistics | Use the existing Courier account password wording; no password-assignment or additional recovery workflow is authorized. |
| Medium | Some root exports abbreviate Task messages to Messages | Preserve the existing full destination name; refinement requested on core roots. |
| Medium | Generated messages/sign-in/screens may include technical authority or privacy banners and unexplained help icons | Remove implementation language and undefined actions; show task-specific recovery wording and only existing controls. |
| Medium | The uncertain-message reference can show Retry and Send competing or an Edit draft action | Freeze the uncertain request, provide exact retry, prevent duplicate sends and retain existing leave/retry behavior. |
| Medium | Light screenshots retain a lavender cast, enlarged identity blocks, generous empty space or small labels | Use repository neutral tokens and compact rows; assess actual readability at 320/390px and 2× text before approval. |
| Medium | Linehaul and batch illustrative display labels are not wire statuses | Render only current server flags/status mappings; batch stays Offered while a current member is unaccepted. Departure requires release plus capability; arrival never receives cargo. |
| Medium | Route fallback invents Auto mode, synchronized manifest and dispatch-release reasons; linehaul adds seal/pallet/manifest details | Remove unsupported metadata and cause explanations. Use the actual returned route reason/flags and existing hub-route presentation only. |
| Medium | Delivery review invents a connected-dispatcher presence and hub cash reconciliation message | Remove presence/connection claims. Show only submitted cash declaration awaiting Logistics validation, without implying a separate hub receipt or paid state. |

## Coverage and validation limits

The exported set covers principal roots and representative workflow states. It does not exhaust six registration steps, profile/security/vehicle forms, ticket detail, camera permissions, policy dialogs, every failure state or dark mode. Existing implementation and owning specs provide that context; this task does not authorize new behavior to fill gaps.

Reviewed generated images statically against familiar Material controls, navigation labels, action hierarchy, essential task context and privacy. No interactive prototype, browser inspector, live Flutter capture, responsive behavior, keyboard interaction, large-text execution, contrast certification, TalkBack/VoiceOver or installed APK acceptance is established by these PNGs. No stock photos or actual private proof were used.

Qualitative result: the structure is useful as a reference set; generated copy and token fidelity still need approval. No numeric accessibility or design score is asserted without measurements.

Documentation checks validated all 16 unique screen IDs, local PNG signatures/dimensions/hashes, nonempty prompts, JSON parsing and documentation links. The progress update preserves the previous bytes as a prefix. Application paths have no diff. Feature-spec inventory found existing out-of-range deferred specs: `profit-dashboard/specs.md` (969 lines) and `incident-reporting/specs.md` (1,073 lines); they were not changed by this task. Other Courier feature specs remain within the required range.

Stitch's project listing exposed four core screens although all 16 initial generated screen IDs could be fetched individually. Local exports and the manifests preserve every reference, including seven later variants; full canvas/list synchronization remains an external-tool limitation. There are 23 PNG exports in total. The issue table describes the initial exports; the six visibly corrected variants are preferable for their respective screens but remain static drafts. The refined registration export remains rejected, and the five core edit screenshots did not refresh.
