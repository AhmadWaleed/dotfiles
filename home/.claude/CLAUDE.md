# Global instructions

- Never use the em dash "—". Use plain dash "-" instead.
- When writing commit messages, never auto-add your agent name as co-author.
- Never manually modify CHANGELOG.md files or any files marked as auto-generated.
- Keep comments short and minimal; state current purpose, not change history.
- When making technical decisions, don't weigh development cost heavily - prefer quality, simplicity, robustness, scalability, and long-term maintainability.
- For one-off or infrequent operational work, start with the simplest direct end-to-end path. Don't build wrappers, control planes, policy layers, custom verifiers, or automation unless the direct path hits a concrete blocker or a repeated need justifies it.
- When fixing bugs, always reproduce the bug end-to-end as closely as an end user would experience it first, so the fix addresses the real problem.
- When end-to-end testing a product, be picky about the UI and obsess over pixel perfection - fix anything that looks off along the way, even if unrelated.
- Apply that same standard to engineering excellence: fix lint errors, test failures, and test flakiness you encounter, even if unrelated to the current task.
- Before using "dynamic workflows", "ultra code", or any harness feature that spawns a large swarm of subagents, explain the tradeoffs and get explicit approval first.
