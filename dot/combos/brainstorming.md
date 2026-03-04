# DOT Combo: Brainstorming

## Trigger
User requests ideation, brainstorming, or creative exploration for a coding task.

## Rules
1. Generate at least 3 distinct approaches before selecting one
2. For each approach, list: pros, cons, complexity estimate
3. Ask the user to pick or combine before proceeding to implementation
4. Keep brainstorming scope-bounded to the current task context

## Routing
- Mode: code (DOT enabled)
- Source: superpowers/brainstorming (migrated)
- Fallback: skip brainstorming phase, proceed with default approach
