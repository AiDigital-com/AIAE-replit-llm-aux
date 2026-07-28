# Task Workspace

This directory stores Claude task artifacts for the current repository.

Recommended per-task structure:

- `.claude/tasks/<task>/plan.md`
- `.claude/tasks/<task>/dev-summary.md`
- `.claude/tasks/<task>/review-report.md`
- `.claude/tasks/<task>/test-report.md`

Do not require a separate `integration-test-report.md` by default. Discover the
test layers that exist in the current repository and record their results in
`test-report.md`. Add a separate report only when an established project
workflow or the user explicitly requires it.
