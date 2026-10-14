# Audit report contract

Read this reference in audit mode. Use the format below without manufacturing findings or claiming unobserved behavior.

## Inspect and prioritize

Review these dimensions where applicable; record not-applicable reasons and incomplete verification:

- Visual hierarchy, spacing, typography, shared theme usage, readable status and essential task context.
- Familiar Material controls, consistent labels, dominant next action, secondary alternatives, consent and confirmation hierarchy.
- Navigation, Back/Cancel, selection/refresh stability, discoverable destinations and draft/discard behavior.
- Plain-language copy, field labels, required indicators, validation, upload feedback and recovery instructions.
- Responsive constraints, wrapping/scrolling, safe areas, keyboard insets, reachable actions and retained context.
- Accessibility: semantics, focus order/visibility/restoration, keyboard actions, touch targets, contrast, non-color status, large text and reduced motion where relevant.
- Light/dark themes and applicable loading, empty, unavailable, forbidden, stale, partial, offline, timeout, validation, throttled, retry, success and pending-review states. Failed reads must not appear empty; unavailable contracts must not generate fake cards or mutation controls.

Priorities reflect user impact, not visual taste:

| Priority | Meaning |
| --- | --- |
| P0 | Essential workflow blocked for affected users, or UI exposes private data/bypasses required authority or consent. |
| P1 | Accessibility failure or major workflow/recovery obstacle; address before consistency/polish. |
| P2 | Usability friction, inconsistent controls/navigation/copy or unclear hierarchy. |
| P3 | Cosmetic polish with working, accessible interactions. |

Adjust severity to demonstrated impact; state assumptions for suspected issues. Group related findings by a common fix, retaining each ID and acceptance criterion. Prioritize blocked workflows and accessibility failures over consistency and cosmetic work. No finding quota.

## Evidence and checks

Use evidence labels on every finding and check:

- **[SOURCE]** File/line and the observed implementation. Source can prove code behavior but does not prove pixels, contrast, keyboard/device behavior, or an assistive-technology result.
- **[AUTOMATED]** Existing command/test target, outcome, and exactly what its assertions cover. A passing analyzer is not a layout/accessibility pass. Historical results are labelled historical with their revision/date and are not reruns.
- **[RUNTIME]** Observed platform, revision, steps, viewport, text scale/theme, state and result with synthetic/redacted data. Existing runtime observation must remain read-only; do not submit live registration, account, upload or operational mutations for an audit.

Mark each finding **confirmed** or **suspected**, stating what evidence supports that confidence. Mark unperformed or unavailable checks **not verified**, with a reason and a supported fallback. Missing runtime tools permit source inspection and existing deterministic checks, not invented runtime observations.

Use existing coverage for the eight combinations of 320×640 and 390×844 logical pixels, 1× and 2× text, and light/dark themes. Report actual assertions per relevant screen/state. Missing combinations, keyboard coverage, browser/device or TalkBack/VoiceOver acceptance are verification gaps, not claims of failure. Existing goldens alone may not exercise full scrolling, focus or state recovery.

Run only existing checks that leave sources, tests, dependencies/lock files, snapshots and tracked configuration unchanged. Prefer `flutter analyze --no-pub` and `flutter test --no-pub <existing-targets>` where supported and dependencies are already resolved. Inspect existing test setup before running commands that could regenerate snapshots or require external services. If safe execution needs repository changes or unavailable tooling, report the limitation and use source/existing evidence. Never use `--update-goldens` or generate previews in audit mode.

## Report format

Create the dated report exclusively, using a numbered suffix on collision. Fill the following sections; omit the sample finding block when no issue is evidenced, and state that the review found no supported findings within its coverage. Preserve evidence and IDs in later improvement work.

```markdown
# Courier Flutter UI audit — {local date}

## Baseline and scope

- Audited Git revision and branch: {full HEAD and branch}
- Working tree: {relevant staged/unstaged/untracked paths, effects on baseline, or clean}
- Backend/API contracts: {adopted versions/commits and source paths; inspected/deployed version separately, unknown explicitly}
- Requested scope: {feature/screens/flow/whole project}
- Actual coverage: {screens, shared components, states, methods and exclusions}

## Coverage inventory

| Screen/route/component | Owning contract | States reviewed | Evidence method | Coverage and remaining work |
| --- | --- | --- | --- | --- |
| {item} | {path/version} | {states} | {SOURCE/AUTOMATED/RUNTIME} | {reviewed/partial/unreviewed with reason} |

For whole-project requests, inventory all discovered screens and shared components,
including dialogs and routed entry points. State discovery limits and incomplete
coverage prominently; do not call partial inspection a complete audit.

## Checks and verification gaps

| Screen/state | Viewport | Text scale | Theme | Evidence/check and result | Gap or limitation |
| --- | --- | --- | --- | --- | --- |
| {item} | {320×640/390×844/other} | {1×/2×/other} | {light/dark} | {[label], target, outcome or not verified} | {reason/fallback/next acceptance} |

Record command outcomes and runtime environment if used. Include keyboard,
semantics/focus and loading/error/recovery coverage beyond the layout matrix.
List unavailable tools, unexecuted checks and relevant historical-only evidence.

## Findings

### UI-001 — {specific user-facing problem}

- Priority: {P0/P1/P2/P3 and impact-based rationale}
- Confidence: {confirmed/suspected; unverified assumptions}
- Screen/state and source: {route/flow/condition; repository-relative file:line and symbol}
- Evidence: {[SOURCE]/[AUTOMATED]/[RUNTIME]; reproducible steps or exact implementation/check; verification limits}
- User impact: {who is affected and what becomes blocked/confusing/inaccessible}
- Applicable rule: {docs/design-courier.md section, project rule, or feature contract path/section}
- Recommended change: {focused fix consistent with Material, architecture and server authority}
- Acceptance criteria: {observable behavior and applicable viewport/text/theme/state/keyboard checks}
- Related findings/dependencies: {IDs to fix together; contract/tool prerequisites or none}

## Prioritized implementation order

| Order | Findings to fix together | Proposed change | Acceptance/checks | Dependencies |
| --- | --- | --- | --- | --- |
| {rank} | {IDs} | {focused implementation} | {testable results} | {contract/tool/prerequisite or none} |

## Contract gaps and handoff

{Exact missing/conflicting endpoint, field, permission or state; authority sources;
which findings/actions are blocked; clarification needed. Separate contract gaps
from missing runtime verification and continue safe independent work.}

{Remaining coverage, device/browser/assistive-technology acceptance and justified
design exceptions. Recommendations do not authorize implementation.}
```

After an explicit improvement request, append dated remediation sections using the improvement reference. Do not replace the audit baseline, evidence, findings, order or prior remediation entries.
