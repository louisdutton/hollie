# Development

- Never run the game, you don't have a graphical environment
- Use `devenv shell` only for one-off commands.
- Do not run routine checks manually. Rely on automated checks unless explicitly asked.
- Commit changes in small, complete, meaningful units. Each commit must leave the application working; do not split a coherent change across commits or create arbitrary checkpoint commits.

## Casing

- **Ada_Case** for types and enum members.
- **snake_case** for procedures/locals/variables/imports.
- **SCREAMING_SNAKE_CASE** for true constants.
