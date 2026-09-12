# Hollie

An Odin and raylib game with local multiplayer, physics, rideable animals, room
puzzles, and an in-game map editor.

## Development

Install Nix and devenv, then initialise the environment and commit hook with a
one-off command from the repository root:

```sh
devenv shell -- true
```

`devenv.lock` pins the environment inputs. `devenv.nix` selects Odin, raylib with
its SDL backend, Python for asset-tool syntax checks, and the formatters.
`RES_ROOT` defaults to `./res`; run commands from the repository root or set it
explicitly.

Follow [AGENTS.md](AGENTS.md). Use `devenv shell` for one-off commands. Agents
must not launch the game or run routine checks manually; rely on the automated
commit hook and CI unless a check is explicitly requested.

On a machine with a graphical environment, developers can launch the debug game:

```sh
devenv tasks run hollie:run
```

F1 toggles the debug map editor; Ctrl+S saves. The full editor action bindings
live in [input/actions.odin](hollie/input/actions.odin).

## Automated verification

The commit hook runs `hollie:verify` for changes to code, resources, asset tools,
environment configuration, formatting configuration, and CI workflows. It:

1. Formats Odin and Nix sources.
2. Checks the debug game and builds the release executable without launching it.
3. Runs the Odin tests across all packages.
4. Validates the room files and their referenced content.
5. Compiles the Python asset-tool sources for syntax errors without importing
   Blender or generating assets.

If formatting changes files, review and stage those changes before retrying the
commit. Build artifacts used by verification live in a temporary directory that
is removed on exit. GitHub Actions runs the same task for pushes and pull
requests and requires formatting to leave a clean diff.

The headless checks do not exercise GPU rendering, audio playback, controller
hardware, or Blender asset generation. Changes to those systems also need a
review on a machine with the corresponding runtime environment.

## Code map

| Location | Responsibility |
| --- | --- |
| `hollie/main.odin`, `scene*.odin` | Application lifecycle, scene selection, pause and transitions |
| `hollie/entity.odin` | World storage, stable entity IDs, relationship cleanup |
| `hollie/simulation*.odin` | Ordered simulation phases and coordination of physics, abilities, and effects |
| `hollie/movement.odin`, `physics.odin`, `collision.odin` | Steering, body integration, collision queries and resolution |
| `hollie/player.odin`, `ai.odin`, `riding.odin`, `ram.odin`, `puzzle.odin` | Gameplay rules |
| `hollie/rendering*.odin`, `graphics/` | World rendering and raylib graphics integration |
| `hollie/tilemap/`, `content/`, `content_validate/` | Room format, content contracts, validation, atomic persistence |
| `hollie/editor*.odin`, `ui*.odin`, `input/` | Map editing, interface layout and controls |
| `hollie/audio/`, `window/`, `tween/`, `asset/`, `spatial/` | Supporting packages |
| `res/`, `tools/` | Source/runtime assets and Blender generators |

[Maintenance conventions](docs/maintenance.md) describe ownership, time,
coordinates, and system dependencies. [Asset tooling](tools/README.md) describes
how generated models relate to their source files.
