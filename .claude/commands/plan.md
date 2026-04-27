Plan a complex feature or architectural change.

## Instructions

1. Gather context:
   - Run `git log --oneline -20` to understand recent changes
   - Read files in the affected areas to understand current state
   - Check for related tests and existing patterns

2. Use the planner agent to design the implementation approach:
   - Identify all affected files across whichever stacks are involved
   - Consider cross-stack impacts (e.g., schema changes that trigger
     client regeneration per the project's api-design rule)
   - Evaluate 2-3 approaches with tradeoffs
   - Design a testing strategy

3. Output a structured plan with:
   - Context and motivation
   - Recommended approach with justification
   - File-level change list (create/modify/delete)
   - Ordered implementation steps
   - Testing plan with specific test cases
   - Risks and open questions

4. WAIT for user confirmation before proceeding with any implementation.

Do NOT start writing code until the user approves the plan.
