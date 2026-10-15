# Development

- Do not launch the game on the host desktop. Use the private-display devenv tasks below for gameplay and rendering tests; they provide their own graphical environment. These tests do not require a separate user request.
- Use `devenv shell` only for one-off commands.
- Do not run routine checks manually. Rely on automated checks unless explicitly asked.
- This project does not use CI; keep verification in the automated local commit hook and do not add CI workflows.
- Document only information that is not easily inferred from the source code itself. Record rationale, constraints, and non-obvious workflows; do not duplicate implementation details, configuration, or command inventories in prose.
- Commit changes in small, complete, meaningful units. Each commit must leave the application working; do not split a coherent change across commits or create arbitrary checkpoint commits.

## Game control and iteration

All rendering and control tools are supplied by `devenv.nix`. Do not install
host tools or connect to the user's desktop. These tasks build the debug game
and launch it on an isolated Xvfb display or headless Gamescope compositor, with Bevy/WGPU Vulkan rendering.
Fullscreen and resolution changes must also be verified through headless Gamescope: the user runs Gamescope with native Wayland clients, and Xvfb/offscreen captures do not exercise its surface size negotiation.
Automation is opt-in via `HOLLIE_CONTROL_DIR` and absent from release builds;
input injection is also available to unit tests.

For a replay test:

```sh
devenv tasks run --show-output hollie:automation-probe
```

This runs the Robot keyboard and two-player gamepad journeys in
`tools/robot/`. It asserts movement, exact frame counts, frozen state between
commands, rejection of invalid commands, and matching state and pixels after a
seeded reset and replay. Each printed temporary artifact directory contains
screenshots, build/runtime logs, Robot reports, and a `commands.json` command/response transcript.
Inspect relevant screenshots and logs as well as the assertions; these scenarios
do not prove all gameplay paths or cross-machine determinism.

For an interactive gameplay test:

```sh
devenv tasks run --show-output hollie:automation-session
```

Alternatively, `devenv --profile automation up` supervises the same private-display
session.

Keep that task running and wait for `Paused control session: /tmp/.../control`.
Use the actual printed directory in separate one-off commands:

```sh
devenv shell -- python3 tools/game_control.py /tmp/.../control '{"op":"reset","room":"demo","players":1,"seed":42,"capture":"start.png"}'
devenv shell -- python3 tools/game_control.py /tmp/.../control '{"op":"step","frames":30,"keys":["S"],"capture":"moved.png"}'
devenv shell -- python3 tools/game_control.py /tmp/.../control '{"op":"observe"}'
devenv shell -- python3 tools/game_control.py /tmp/.../control '{"op":"stop"}'
```

- `reset` starts the specified room with one or two players and a random seed;
  defaults are `demo`, one player, seed 42. It clears held inputs and frame count.
- `step` advances 1–600 frames at 1/60 second per frame. Each command supplies
  the complete held input snapshot; omitted keys and gamepads are released.
  Holding an input across consecutive steps preserves it. A `pressed` edge is
  visible to all readers for the first simulation frame after a new press.
- The control protocol retains legacy key names, such as `S`, `SPACE`, or `ENTER`.
  Gamepads specify `Player_1` or `Player_2`, legacy button names, and axes in order
  `LEFT_X`, `LEFT_Y`, `RIGHT_X`, `RIGHT_Y`, `LEFT_TRIGGER`, `RIGHT_TRIGGER`, with
  values from -1 to 1. For example:
  `{"op":"step","frames":30,"gamepads":[{"player":"Player_1","axes":[0,1],"buttons":["RIGHT_FACE_DOWN"]}]}`.
- `observe` reports state without advancing time. Responses include frame,
  room, player positions/velocities, enemy movement state, and an `error` field.
  Check errors before interpreting the result.
- Optional `capture` takes a plain PNG filename. The response gives its absolute
  path; inspect that image. Bevy captures the rendered frame asynchronously;
  simulation stays frozen until the capture finishes and the response is published.
- `stop` closes the game. The launcher cleans up the game, window manager, and
  display on exit/failure, and limits interactive sessions to five minutes.

Use one controller per session and send commands sequentially. The Python client
handles atomic request files, increasing IDs, matching responses, and timeouts.
Simulation advances only through `step`.

For a code iteration: reproduce the issue, capture/observe it, stop the session,
edit the code, then launch again to rebuild and replay the same inputs and seed.
Save reusable command sequences and assertions as Robot journeys and resource
keywords in `tools/robot/`; register new regression journeys in the
`hollie:automation-probe` task. Do not rely on temporary transcripts as the only
record of useful interactions. Keep routine checks in the automated commit hook.

Combine related checks into coherent Robot journeys when they can share a session.
Keep each journey in a fresh private game process and its commands sequential.
Title audio and first-entry checks must retain a fresh title-screen start; do not
add an implicit gameplay reset. Use resource keywords for shared routes and native
Robot assertions.
`Sleep` waits in wall time with simulation frozen; advancing gameplay requires
explicit tick commands, including any release ticks between repeated presses.

Run independent journeys in bounded, balanced groups through native devenv tasks,
with separate displays, control directories, and artifacts for each session.
Keep build dependencies and caching in devenv, and execute the shared built binary
directly to avoid duplicate build orchestration and large per-journey snapshots.
Tune concurrency and group balance from measured durations and CPU, RAM, and GPU
usage. When changing replay execution, preserve simulation and animation updates;
verify matching observed state and captured pixels with the same inputs and seed.

Review and commit generated assets with their sources when explicitly baking
assets; do not regenerate assets as part of routine verification.

Set `HOLLIE_GPU_DEVICE` to a WGPU adapter-name substring before the task to select
a particular GPU. Hardware tasks fail if the GPU is unavailable
or software rendering is detected. For a rendering smoke
test, `hollie:render-probe-gpu` uses hardware and `hollie:render-probe` requests a
software Vulkan adapter. Those smoke probes do not provide deterministic replay.
See [README.md](README.md#agent-control-and-replay) for further context.

## Casing

- **Ada_Case** for types and enum members.
- **snake_case** for procedures/locals/variables/imports.
- **SCREAMING_SNAKE_CASE** for true constants.
