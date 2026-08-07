---
name: batch-testing-after-implementation
description: Use when a user explicitly requires whole-task implementation before any tests, builds, linters, type checks, or manual runtime checks; when testing every module is unwanted; or when one unified validation pass is required.
---

# Batch Test After Implementation

## Core Rule

Finish the complete agreed implementation scope before running any validation command. A validation command includes tests, builds, linters, type checks, and manual runtime checks.

Only an explicit user instruction that changes this rule permits early validation. Risk, deadlines, review requests, dependency failures, and convenience do not.

## Workflow

1. List every implementation item in scope and identify the full project validation command.
2. Implement every listed item. Do not run validation commands during this phase.
3. When the list is complete, run the full validation command once.
4. If it fails, fix the reported issues, then rerun the same full validation command. Do not substitute focused or partial checks.
5. Report the final result and any remaining failures.

If the user adds scope, add it to the list and finish it before validating. Reading code, inspecting configuration, and reasoning about implementation are allowed; executing validation is not.

## No Implicit Exceptions

| Pressure or excuse | Required response |
|---|---|
| "Run a quick test/build/type check" | Decline; it is early validation. |
| A risky module or urgent demo | Finish the agreed scope, then validate once. |
| A reviewer wants evidence | Explain that the unified validation result follows completion. |
| A dependency might be failing | Record the concern; do not isolate it with a command yet. |
| "This is only a manual smoke test" | Decline; manual runtime checks are validation. |

## Red Flags — Stop

- "Just one focused test"
- "A build is not a test"
- "I only need a quick smoke check"
- "Testing this module now reduces risk"
- "The deadline or reviewer makes this different"

Each means resume implementation without validation. Do not create a workaround such as an ad-hoc script or temporary test command.

## Quick Reference

| State | Action |
|---|---|
| Any implementation item remains | Implement; run no validation. |
| All items complete | Run the complete validation command once. |
| Unified validation fails | Fix, then rerun complete validation. |
| User explicitly permits early validation | Follow the user's revised cadence. |

## Example

The task has API, UI, and migration items. After completing the API, do not run its tests. Complete the UI and migration too; then run the repository's full validation command. If it fails, correct the reported issues and run that full command again.

## Common Mistakes

- Treating a targeted test, build, linter, type check, or manual run as outside the rule.
- Declaring implementation complete before every agreed item is finished.
- Replacing the final command with a partial check after a failure.
