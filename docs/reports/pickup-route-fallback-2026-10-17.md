# Pickup route fallback fix — 2026-10-17

## Baseline and confirmed issue

- Direct issue: Pickup route order promises a stop list after “Map unavailable,” but no stops appear. The selected recovery is a return to the existing pickup tasks and their authorized details.
- Flutter baseline: `d249d513de887e4bae559421de29c8cf79b89d41` on `main`, with a clean working tree. Created `fix/pickup-route-empty-fallback` before edits.
- Adopted contracts: Pickup spec v2.11 / `first-and-final-mile-pickup-v1-tracking-id`, backend `d5c160d4a5a21272e487b6f46a82de35e81395cb`; map baseline `51d96947569d1603fdfb6d264ebd2a04bf866280`. Latest recorded unrelated registration implementation remains `27a6361`. Deployed revision is unidentified.
- **[SOURCE, confirmed]** At the baseline, the [shared map fallback](../../lib/shared/route_map/route_map_view.dart) unconditionally promised stops below. [Pickup route rendering](../../lib/features/pickup/presentation/components/pickup_route.dart) only rendered `manifest.stops`, replaced an empty list with “No route stops are assigned right now,” and could simultaneously claim an ordered route for an empty `ready` result.
- **[SOURCE, confirmed]** The [manifest parser](../../lib/features/pickup/domain/models/pickup_route_models.dart) silently converted non-null, non-list `stops` into an empty list. This hid an invalid response as missing route data.
- **[AUTOMATED]** Before production edits, the first 17 new regression cases produced 9 passes and 8 failures: four empty-state cases and four malformed-list cases. Existing selected route/repository checks passed (22 tests).
- Impact: misleading availability and recovery guidance (P2). These findings do not establish why the reported deployed manifest/map was unavailable; no live private response was observed.

## Implemented behavior

- Shared, pickup, and delivery map-failure messages describe only the map. Owning screens retain their independent stop-list presentation.
- Pickup banners distinguish pending, ready-without-stops, unavailable, and unsupported responses. They only refer to a list below when returned stops exist. Empty route data never implies no pickup work is assigned or that an ordered route exists.
- Empty manifests offer primary **Back to pickup tasks**, using the existing Navigator return, with **Refresh route** secondary. Selected schedules, task snapshots, and list scroll remain in the owning pickup screen.
- Returned stops, grouped Order references, and hub start/return remain readable independently of coordinates, disabled maps, or renderer failure. No fallback tasks, coordinates, order, or authority are fabricated.
- A non-null, non-list `stops` now throws `ApiContractException`, reaching existing recoverable error/retry handling. Existing missing/null compatibility and explicit empty lists are retained.
- Reused the existing Material banner/card, buttons, theme, and navigation. Availability text is a semantic live region; controls remain scrollable with large text. No design-guide exceptions were needed.
- Endpoint paths, bearer transport, permissions, state transitions, dependencies, copied contracts, and environment configuration are unchanged. The pickup spec remains 230 physical lines; the affected hand-written component is 365 lines.

## Fresh verification

All checks below use synthetic responses. Tests ran with `--no-test-assets`, without reading or bundling the local `.env`.

| Check | Result and coverage |
| --- | --- |
| `flutter analyze --no-pub` | Pass, no issues. |
| `flutter test --no-pub --no-test-assets test/features/pickup test/features/delivery_route test/shared/route_map` | Pass, all 169 tests, including 60 new model, screen, and recovery cases. |
| Pickup empty-state matrix | All four route states at 320×640 and 390×844, 1×/2× text, light/dark; complete scrolling, Android/iOS target size, labels, contrast, and no layout errors. |
| Pickup map fallback | At 320×640 / 2× text in light/dark, missing coordinates, disabled maps, and injected renderer failure preserve readable stops. Mock style/tile requests remain zero in these scenarios. |
| Recovery/navigation | Empty-to-populated refresh, malformed-list Retry, `429` cooldown/no automatic retry, keyboard activation of Back preserving schedule/tasks/scroll, and map revalidation replacing populated stops with an empty result. |
| Scope/session loss | `401`, `403`, and `409` remove route snapshots; session invalidation closes a pushed route and ignores a late in-flight manifest. |
| Shared consumers | Existing delivery-route accessibility, map-failure, navigation, and session-cleanup regressions pass; disabled-map Android platform-variant check passes. |
| Formatting and Git checks | Changed Dart files formatted; scoped diff and whitespace checked; no unrelated or secret files included. |

The investigation's SDK-cache restriction was resolved for verification through scoped execution access. These results are host unit/widget checks, with injected map failure where applicable; they do not certify native MapLibre or browser rendering.

## Remaining acceptance

- DTD discovery found no running debug app, so no hot reload or live screen observation was available.
- No installed-APK, localhost browser, TalkBack/VoiceOver, deployed API, or provider/manifest-generation acceptance was performed. The server-side reason for the reported missing map/stops remains unverified.
- The fix implements honest fallback and recovery. Any later investigation of unavailable server route generation must use its authoritative response/contract rather than infer missing assignments from this screen.
