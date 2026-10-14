---
name: courier-ui-review
description: Audit Courier Flutter features, screens, flows, or the whole project into actionable UI reports, and implement explicitly requested findings or UI fixes. Use for Courier UI review or improvement requests; default to audit mode.
---

# Courier UI review

Keep the existing Courier design language and produce evidence-based findings or scoped improvements. Creating or updating this skill does not authorize an application audit.

## Select the mode

- **Audit (default):** Inspect the requested feature, screen, flow, or whole project and write a new report. Recommendations never authorize fixes.
- **Improve:** Require an explicit request naming a report and findings, asking to “improve this report” (its actionable findings), or directly describing a UI issue to fix. A narrow issue needs no prior report. Resolve ambiguous report references or finding selections before dependent edits; continue independent inspection.
- Stay within the requested scope. Revalidate findings before editing; do not turn a selected-finding fix into a whole-project redesign.

## Establish project authority

1. Read `docs/PROGRESS.md` first. Record the latest Flutter work and relevant adopted backend/API versions; distinguish inspected source revisions from adopted and deployed versions. Do not freeze version values in this skill.
2. Follow root and applicable nested `AGENTS.md`, `docs/design-courier.md`, `docs/features/courier/rules.md`, and existing architecture in `docs/architecture.md`. Read matching Courier feature contracts completely, preserving `spec.md` or `specs.md` paths, plus applicable endpoint notes/version records.
3. Read Courier-related sections of `docs/requirements.md`, `docs/workspace.md`, `docs/schema.md`, and `docs/domain/Courier.md`. Read `docs/domain/Logistics.md` for affiliation/hub/task authority, registration requirements for registration/approval, and file-upload requirements plus `docs/flutter-file-uploads.md` for uploads/private previews, as project rules require.
4. Capture the Git revision, branch, and relevant staged, unstaged, and untracked changes. Inspect only relevant non-secret paths; preserve pre-existing work and distinguish it from this task's changes.

Preserve Flutter/Dart architecture, state management, routing, networking, shared themes, null safety, approved dependencies, and familiar Material interactions. Follow Jakob's Law and Hick's Law: stable labels/navigation, one prominent next action when applicable, discoverable secondary choices, progressive steps, essential context, explicit consent, and required confirmations.

Laravel remains authoritative for identity, affiliation, sole hub, ownership, eligibility, fields, statuses, and transitions. Distinguish implemented, scaffold-only, planned, and unavailable behavior. Do not enable mutations or invent backend behavior to satisfy a UI recommendation. Missing or conflicting authority blocks only the dependent recommendation/fix; document the contract gap and proceed with independent authorized work.

Use synthetic or redacted evidence. Never read or modify secret-bearing `.env` files, expose credentials, private images, raw private storage paths, or unnecessary personal data in reports, fixtures, logs, or screenshots. Keep tokens in approved secure storage; authenticated browser observation requires the documented web-storage boundary. Preserve Android and the same Flutter localhost web-server app; add no packages/frameworks without explicit approval.

## Audit

Read [references/report-template.md](references/report-template.md) for the inspection checklist, evidence rules, priority definitions, and report format.

- Inventory screens, routes, dialogs/forms, and shared components for whole-project scope. Map each to its owning contract and list reviewed, partially reviewed, and unreviewed areas with reasons. For narrower scope, report actual screens/states reviewed and exclusions.
- Inspect code and existing tests. Run relevant existing non-mutating checks when available, covering 320×640/390×844, 1×/2× text, light/dark, and applicable keyboard/state behavior. Missing coverage is a verification gap, not proof of failure.
- The only repository edits are a new report and required progress documentation/archive. Do not fix app code, add/change tests, generate previews, rewrite snapshots/goldens, update dependencies, or modify contracts/design guides. Read helper skills only when relevant and restrict any mutating guidance to improve mode.
- Create `docs/reports/flutter-ui-audit-YYYY-MM-DD.md` using the local date. If occupied, use `-2`, `-3`, etc.; create exclusively and never overwrite a report. Findings have stable report-local `UI-001` IDs; always pair IDs with the report path.
- Append a dated progress entry recording scope, report link, backend/API versions, checks, and gaps. Apply the progress archive rule below. Verify the final diff contains only allowed task edits; never revert someone else's work to clean a check's output.

## Improve

Read [references/improvement-workflow.md](references/improvement-workflow.md) for revalidation, installed-skill routing, implementation, verification, and append-only remediation.

Follow project feature-branch rules before editing, run `flutter analyze` and relevant `flutter test` targets for application changes, and follow focused conventional-commit rules unless the user requests no commit. Review familiar controls, action hierarchy, secondary choices, stable navigation, workflow context, focus, text scaling, and themes against the design guide. Preserve original report evidence and append results; separate implemented fixes from pending device/browser acceptance.

## Progress archive rule

Append dated entries without rewriting history. After appending, if `docs/PROGRESS.md` exceeds 150 physical lines, preserve its complete contents unchanged in `docs/logs/PROGRESS-YYYY-MM-DD.md` (unique numbered suffix if needed; never overwrite). Replace the active log with its standard header, current backend/API and Flutter-status snapshot, and a dated entry linking the archive and summarizing the latest work. Read earlier archives only when relevant.

## Example requests

- `$courier-ui-review audit the registration and account screens. Write the report under docs/reports. Do not modify application code.`
- `$courier-ui-review improve UI-001 through UI-004 from docs/reports/flutter-ui-audit-2026-10-14.md.`
- `$courier-ui-review fix the Account dialog's clipped Save action at 2× text.`
