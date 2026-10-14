# Hollie

A Rust and Bevy game with local multiplayer, physics, rideable animals, room
puzzles, and an in-game map editor.

## Development

Install Nix and devenv, then initialise the environment and local commit hook:

```sh
devenv shell -- true
```

Follow [AGENTS.md](AGENTS.md). This project does not use CI; verification runs
through the local commit hook. If formatting changes files, review and stage
those changes before retrying the commit.

See [devenv.nix](devenv.nix) for tasks, optional profiles, and release packaging.
The release output is a native Nix package; distributing it to machines without
Nix requires a separate packaging step.

## Agent control and replay

Use the private-display workflow in [AGENTS.md](AGENTS.md) for gameplay and
rendering tests, and save useful regression
interactions in `tools/scenarios/` rather than relying on temporary transcripts.

Inspect screenshots and runtime logs as well as assertions. Smoke captures do
not establish shader correctness, deterministic replay, or GPU performance.
Seeded replay establishes repeatability for the tested scenarios in the current
environment, not across GPUs or all gameplay paths.

Hardware rendering requires an installed kernel driver and Vulkan-capable GPU
device access; devenv supplies the user-space tools and libraries. Use the software
probe separately when hardware is unavailable.

Headless verification does not exercise GPU rendering, audio playback, controller
hardware, or Blender asset generation. Changes to those systems also need review
in the corresponding runtime environment.

[Maintenance conventions](docs/maintenance.md) cover project ownership and
conventions. [Asset tooling](tools/README.md) covers generated-asset maintenance.
