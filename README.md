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
commit hook unless a check is explicitly requested.

On a machine with a graphical environment, developers can launch the debug game:

```sh
devenv tasks run hollie:run
```

F1 toggles the debug map editor; Ctrl+S saves. The full editor action bindings
live in [input/actions.odin](hollie/input/actions.odin).

For an explicitly requested rendering smoke test, run:

```sh
devenv tasks run --show-output hollie:render-probe
```

This builds the debug game and launches it on a private 1280×720 Xvfb display
with Openbox and Mesa software OpenGL, using tools provided by devenv. It focuses
the game, captures the title screen, presses Enter to start one-player gameplay,
captures that view, and presses Backspace to exit. Each stage has a timeout;
the game, window manager, and display are cleaned up on failure too.

The printed temporary directory retains screenshots, the executable, and logs
for inspection. Inspect both images and `game.log` before declaring the probe
successful: screenshots alone do not assert the current scene or shader correctness.
This is a visual smoke test, not a deterministic replay or a GPU performance test.
Agents need explicit authorization to run it under the current `AGENTS.md` rules.

On a Linux machine with an accessible AMD GPU and Mesa drivers, use the hardware
variant of the same probe:

```sh
devenv tasks run --show-output hollie:render-probe-gpu
```

VirtualGL uses EGL to render on the GPU and copies frames to the private Xvfb
display. The probe checks the renderer and fails if it identifies a software
renderer. Both probes use the same 1280×720 display and input sequence.
`devenv.nix` pins VirtualGL 3.1.5 for its
[SDL resize fix](https://github.com/VirtualGL/virtualgl/releases/tag/3.1.5),
and supplies Mesa, SDL3, and the EGL loader paths for the GPU process.

The default GPU is `egl0`; EGL numbering depends on the machine. To select another
device, set `HOLLIE_GPU_DEVICE` to an EGL device ID or a DRI card path:

```sh
HOLLIE_GPU_DEVICE=egl1 devenv tasks run --show-output hollie:render-probe-gpu
```

The GPU needs an installed kernel driver and device access; devenv provides the
user-space tools and libraries. The GPU probe fails explicitly when unavailable;
the software probe remains a separate fallback. These captures are smoke tests,
not repeatable performance benchmarks.

## Agent control and replay

For an explicitly requested control test, run:

```sh
devenv tasks run --show-output hollie:automation-probe
```

This runs saved keyboard and two-player analog gamepad scenarios on the GPU.
They reset the demo room with a fixed random seed, advance exactly 30 frames,
and compare observations and captured pixels after replay. They also check that
waiting leaves the simulation frozen and invalid commands leave it unchanged.
Each printed artifact directory contains screenshots, logs, and a `scenario.json`
command/response transcript. The scenarios live in `tools/scenarios/`; store
reusable interactions there rather than rediscovering inputs on every iteration.
These tests establish repeatability for those scenarios on this environment;
they do not establish determinism across GPUs or all gameplay paths.

To interact with a paused game, start a session:

```sh
devenv tasks run --show-output hollie:automation-session
```

Wait for `Paused control session: /tmp/.../control`, then use that exact directory
in one-off commands from another terminal:

```sh
devenv shell -- python3 tools/game_control.py /tmp/.../control '{"op":"reset","room":"demo","players":1,"seed":42,"capture":"start.png"}'
devenv shell -- python3 tools/game_control.py /tmp/.../control '{"op":"step","frames":30,"keys":["S"],"capture":"moved.png"}'
devenv shell -- python3 tools/game_control.py /tmp/.../control '{"op":"observe"}'
devenv shell -- python3 tools/game_control.py /tmp/.../control '{"op":"stop"}'
```

Responses include frame count, room, player positions and velocities, enemy
movement state, errors, and the absolute path of any requested PNG. Screenshots
come directly from the completed game back buffer before swapping, avoiding
delayed desktop captures. Sessions clean up on exit or after five minutes.
Close the session, edit code, and launch again to rebuild; saved scenarios can
be replayed through the Python client's `run_scenario` function.

The control interface is compiled into debug builds only and enabled only when
`HOLLIE_CONTROL_DIR` names an existing directory. One controller submits sequential
commands through atomic `request.json` writes and waits for the matching
`response.json`; the Python client assigns increasing IDs and enforces a timeout.
The game stays responsive and renders while waiting, but simulation time advances
only through `step`, at 1/60 second per frame, for 1–600 frames per command.
`reset` defaults to room `demo`, one player, seed 42.

Each step supplies the complete held input snapshot: omitted keys or gamepads
are released. Holding a key across consecutive steps preserves its state;
`pressed` fires only on a rising edge and remains visible to every input reader
for that simulation frame. Gamepads use raylib button names and axis order
`LEFT_X`, `LEFT_Y`, `RIGHT_X`, `RIGHT_Y`, `LEFT_TRIGGER`, `RIGHT_TRIGGER`, with
values from -1 to 1. For example:

```json
{"op":"step","frames":30,"gamepads":[{"player":"Player_1","axes":[0,1],"buttons":["RIGHT_FACE_DOWN"]}]}
```

All tools are supplied by devenv. Agents still need explicit authorization to
launch these sessions under `AGENTS.md`.

## Automated verification

The commit hook runs `hollie:verify` for changes to code, resources, asset tools,
environment configuration, and formatting configuration. It:

1. Formats Odin and Nix sources.
2. Checks the debug game and builds the release executable without launching it.
3. Runs the Odin tests across all packages.
4. Validates the room files and their referenced content.
5. Compiles the Python asset-tool sources for syntax errors without importing
   Blender or generating assets.

If formatting changes files, review and stage those changes before retrying the
commit. Build artifacts used by verification live in a temporary directory that
is removed on exit.

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
