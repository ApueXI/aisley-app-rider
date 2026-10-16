# Improvement workflow

Read this reference only for an explicitly requested improvement. Keep the report path and selected IDs attached to every decision.

## Scope and revalidation

- A report-plus-IDs request authorizes those findings. “Improve this report” authorizes its actionable findings within project constraints. A directly described UI fix authorizes that issue without requiring a prior audit; record its baseline, acceptance, changes and limitations in progress documentation rather than launching a broader audit.
- Read the selected report and follow the shared project-authority steps. Compare its revision, affected symbols, working-tree changes and contracts to current code. Reproduce with safe existing checks/observation where supported before editing.
- Record each finding as still applicable, already resolved, stale/no longer reproducible, or blocked. Preserve the original evidence; explain changed code/contracts or unavailable reproduction. Do not blindly apply a stale recommendation or claim resolution from missing runtime evidence.
- Define testable acceptance criteria and related fixes within the authorized selection. Inspect shared-component consumers for regressions; if an unselected finding needs independent work, document it without expanding scope.
- Stop the dependent fix when it needs undocumented/unimplemented backend behavior, unapproved dependencies, or conflicting privacy/authority. Name the exact gap and safe next step; continue independent authorized fixes. Keep a safe scaffold where project rules require it, without enabling a guessed API action.

## Resolve installed helpers

Resolve each applicable `dart-flutter` skill by its logical name in the **current available skill catalog**, then read the returned `SKILL.md` through its declared access mechanism. Never hardcode plugin versions, cache directories or assumed tool names. Read only skills that help the selected work. A helper's creation/mutation instructions apply only to improve mode and cannot override project rules or the user's scope.

| Selected task | Skill name to resolve |
| --- | --- |
| Adaptive layouts | `flutter-build-responsive-layout` |
| Overflow or constraints | `flutter-fix-layout-issues` |
| Useful component previews | `flutter-add-widget-preview` |
| Widget behavior/accessibility checks | `flutter-add-widget-test` |
| Flow-level verification | `flutter-add-integration-test` |
| Runtime failures | `dart-fix-runtime-errors` |
| Analysis | `dart-run-static-analysis` |
| Necessary feature-local restructuring | `flutter-apply-architecture-best-practices` |

Resolve names with their catalog namespace (for example, `dart-flutter:flutter-add-widget-test`) and use the catalog's current location. Do not load every helper by default. Generate previews only when useful and compatible with existing dependencies; never add packages without explicit approval. Integration setup and architecture helpers must not broaden a UI fix into unrelated configuration or restructuring. Review any automated lint fix before applying it; avoid unrelated bulk changes.

If a skill or runtime/LSP/preview/integration tool is missing, report that limitation and use supported source inspection, Flutter CLI analysis and existing widget/flow checks. Add focused meaningful tests in improve mode when needed by the change and project gate. A fallback does not establish device/browser/runtime acceptance.

## Implement and verify

1. Before edits, create/switch to a descriptive feature branch derived from the current Flutter branch as `AGENTS.md` requires. Preserve unrelated work; do not reset or commit it.
2. Keep rendering in widgets, transitions in cohesive controllers, requests in repositories and parsing in models. Reuse existing Material components/themes and familiar navigation. Split only affected files when their complexity/responsibilities require it; retain approved packages, privacy boundaries and server-derived actions/states.
3. Format changed Dart files. Run `flutter analyze` and relevant `flutter test` targets. Exercise meaningful regression/behavior/accessibility coverage for the changed workflow, including relevant 320×640/390×844, 1×/2× text and light/dark combinations. Validate familiar controls, one prominent available next action, discoverable alternatives, stable Back/Cancel/navigation, focus/keyboard behavior, essential context and applicable loading/error/recovery states.
4. Use supported runtime checks for the affected Android and same-app localhost browser targets when available. Observe current consent/privacy/secure-storage rules; no real operational mutation merely to verify appearance. Do not equate widget tests or builds with installed-APK, browser camera/upload, or assistive-technology acceptance. Record absent coverage/tools honestly.
5. Check the final diff for scope, contract/privacy preservation and regressions in affected shared consumers. Verify applicable spec line bounds, endpoint/version references and copied-document synchronization if those documents changed; do not rewrite contracts simply to justify a fix.
6. Append remediation below and a dated `docs/PROGRESS.md` entry with report/IDs (or direct issue), adopted backend/API version, changes, checks and pending acceptance. Apply the entrypoint's 150-line archive rule; preserve archives unchanged.
7. After completion and required verification, make a focused conventional commit per project rules unless the user says to leave changes uncommitted. Stage only authorized files/hunks; exclude secrets, generated credentials, device data and unrelated changes. If required checks cannot run or fail, report incomplete verification and do not claim the feature verified.

## Append remediation without rewriting evidence

Append a dated section to the original report for selected-report work. Preserve its entire pre-remediation contents and every earlier remediation entry unchanged. Repeated passes add another dated section; never renumber or reuse finding IDs. Describe new issues separately rather than silently adding them to the authorized selection.

```markdown
## Remediation — {date, optional pass number}

- Request: {report path and selected IDs, or all actionable findings}
- Current Git baseline/branch: {revision, relevant existing changes}
- Backend/API version: {adopted versions/commits and contract references}

| Finding | Current-code revalidation | Changes/source | Checks and outcome | Remaining limitations/status |
| --- | --- | --- | --- | --- |
| UI-001 | {applicable/already resolved/stale/blocked plus evidence} | {files/behavior, or no edit with reason} | {[SOURCE]/[AUTOMATED]/[RUNTIME], actual results} | {implemented and verified to stated extent/device-browser acceptance pending/blocked/not applied} |

{Acceptance criteria achieved and still open; related findings handled together;
blocked contract decisions, unselected related work, tool/coverage gaps; commit
if made or explicitly uncommitted. Retain separate implementation and live
acceptance claims.}
```

For a direct issue without a report, include equivalent revalidation, acceptance, results and limitations in the progress entry and handoff. Do not create a pretend original audit or invent a prior finding ID.
