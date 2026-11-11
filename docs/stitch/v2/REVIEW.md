# V2 static design review — 2026-11-12

These designs are exploratory references. No image is approved for Flutter adoption. A generated description claiming strict compliance is not verification. The [context](CONTEXT.md) and owning feature contracts take precedence.

## Initial exports

All 16 initial PNGs were retrieved through Stitch `download_file`; principal core screens were viewed individually and the ten auxiliary exports were inspected in two contact sheets. The following observations describe pixels, not merely generator summaries.

| Screen | Useful structure | Required correction |
| --- | --- | --- |
| Home | Active/available separation, per-section time, stale row, owning-feature links | Remove menu, synthetic rider ID, boxed-icon shortcuts and left accent rail; compact identity and preserve exact Task messages casing. |
| Work | All five workflow rows and four destinations | Serif rendering is wrong; use the existing sans-serif TextTheme. Remove invented menu/bell. |
| Task details | Area-safe offer, explicit Accept delivery, secondary rejection/chat | Reference breaks over lines; separate it from the status. Remove RIDER V2 badge and invented dispatch-window claim. |
| Pickup scan review | Read-only candidate, automatic type, Scan again and Confirm pickup | Code128 capture does not prove a manifest match. Remove verification-success claim, step badge and fake QR decoration. Keep server confirmation boundary. |
| Delivery photo/cash | Correct PHP 115.00, unchecked cash checkbox, disabled Delivered and review helper | Remove service level/prerequisite labels/mockup metadata; restore all existing retake/replace/remove choices and authorized destination context. Preview is illustrative only. |
| Task messages | Task reference/leg, counterpart, read/unread text | Remove shift/priority tiles, Live Hub, ETA, bay metadata and policy banner. These are invented structured facts. |
| Account | Existing grouped settings, Appearance and Sign out | Remove menu/bell/version, use initials instead of generated person photograph, restore Account title. No identity-photo artifact is approved as a real rider photo. |
| Sign in | Email/password visibility, Sign in/Create account | Remove invented encryption guarantee, version, portal footer and filled password depiction. No new password recovery flow. |
| Registration OTP | Automatic-submit explanation, resend/cooldown, Back to review and Verify and submit | Replace six separate boxes with the existing single empty code field. Remove step-count and activation/dispatch-inbox language. Confirm persistence before pending-success state. |
| Final-mile batches | One accepted and two offered independent parcel rows; accepted-only route | Remove invented sectors, weights/package classification and unnecessary full street. Review rows must not compete as multiple prominent actions. |
| Delivery history | Exact reference Search/Clear, area-safe delivered row and proof status | Remove copy icon/archive/verified-query claims. Illustrative timestamp is not current backend evidence. |
| Notifications | Status/category filters and explicit unread rows | Support comes from Admin platform support; remove Logistics-desk response. Remove unsupported linehaul navigation and task-action phrasing. Opening never marks read. |
| Pickup route unavailable | Honest empty route and correct Back to pickup tasks/Refresh route | Remove kebab and invented cause (unassigned pins/pending sequence); empty route does not prove empty work. |
| Linehaul arrival reported | Origin/destination, In transfer, arrival time and wait for Logistics | Remove sealed bins, staging bay, gate acknowledgment, custody/manifest summary and location claims. Arrival report does not receive parcels. |
| Delivery awaiting review | Separate review state, photo/cash submission summary and refresh | Remove automated inspection pipeline, turnaround, Logistics Unit 4, fake timestamp/manifest, package-slip match, cargo release and automatic 30-second polling. No delivered/paid claim. |
| Policies consent | Two visible unchecked selections and one disabled acceptance | Remove fabricated telemetry/GPS policy, regulations and effective dates; use Terms of Service and Privacy Policy. Preview text is synthetic, never official legal text. Preserve full readable documents in implementation. Exact action is Accept. |

## Refinement request

One explicit correction request covers all 16 initial screen IDs. It asks for fresh retrievable screenshots, removes the unsupported claims above and preserves each existing workflow. The exact request, responses, IDs and local file hashes are retained alongside the exports. A successful edit acknowledgment alone does not prove a screenshot changed; compare file references and hashes and inspect the downloaded pixels.

## Review method and limits

### Retrieved refinement evidence

The edit returned 16 new resources named `V3 ...` within the **AISLEY Rider V2** project; this is Stitch's iteration naming, not a third project or API version. All 16 fresh PNGs were downloaded and inspected in [four](refined-sheet-1.png) [contact](refined-sheet-2.png) [sheets](refined-sheet-3.png) [here](refined-sheet-4.png). Each has its own screen/file ID and hash.

Visible improvements: Home loses the fake rider ID/menu and uses compact shortcuts; task references no longer split; scan review loses the unsupported manifest match; Messages loses shifts/priority/live-hub/ETA; Account uses initials and its proper title; sign-in removes encryption/version claims; OTP now has one field; batches use safe areas and secondary decisions; history/notifications remove extra controls; route fallback removes its invented cause; linehaul removes staging/manifest/quantity details.

Remaining issues after that pass: Work still renders in serif despite the tool saying otherwise; delivery awaiting review still describes an automated inspection pipeline, cargo release and a rider-dropoff timestamp; policy text still invents telemetry/transport obligations and says Accept policies. These three are unsuitable references and receive new minimal regeneration briefs. Linehaul retains an unnecessary Gate checkpoint label; remove it before adoption. The delivery photo draft now uses a file-summary placeholder rather than the existing image preview, which must remain available in any implementation. Some task rows retain boxed icons, banners, tight labels or excessive whitespace. These are unfinished visual references.

The final minimal generation request also proposed thread retry, support-ticket detail and dark Appearance references. It returned an HTTP transport error without screen IDs. It was not retried, because a disconnected request can still run remotely. Subsequent project/list reads exposed only the original 16 screens; even the 16 successfully retrieved refinement resources are absent from those listings. The local manifest therefore records individually retrieved resources as stronger evidence than listing completeness. No final-generation success, dark variant, thread or ticket PNG is claimed. Its prompt and error remain in provenance for a later session to reconcile before another generation request.

The direction retains familiar Material navigation, labelled controls and one main decision. The screenshot families vary in density; generous spacing, excessive metadata, boxed icons and inconsistent typography require correction. The high-priority issues are authoritative meaning (scan/review/arrival), invented operational fields and consent content. These outweigh cosmetic polish.

No measured accessibility score is asserted. Static screenshots cannot establish functioning 48px targets, text reflow, full document scrolling, focus order, validation, keyboard insets, retry locking, screen-reader announcements or responsive behavior. No stock photo search, live API, Flutter runtime, browser inspector, analyzer/test/build or installed-device acceptance was performed. The generated rider photograph is not an approved source asset; no downloaded proof depicts a real delivery.

The set is representative, not exhaustive: it does not specify every registration field/step, profile/password/vehicle form, ticket/thread/media state, camera permission, map fallback or error condition. Existing code/contracts still own those behaviors. Tool suggestions for dark variants, extra parcel detail and interactive prototypes are recorded as suggestions; they do not authorize new behavior or prove those outputs exist.
