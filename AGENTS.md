# Development

- Design controls and on-screen prompts for gamepad first, with keyboard fallbacks.

- Do not launch the game on the host desktop or connect to the user's desktop. Use the private-display workflow below; gameplay and rendering tests do not require a separate user request.
- Use tools supplied by `devenv.nix`; do not install host tools. Use `devenv shell` only for one-off commands.
- Production builds are opt-in; keep them out of normal development and commit verification.
- Do not run routine checks manually unless explicitly asked. Verification belongs in the automated local commit hook. This project does not use CI; do not add CI workflows.
- Define test cases and setup in the test suite. Devenv tasks build and run the whole suite; use the runner CLI for selection, and devenv scripts only for workflows the runner cannot express.
- Document only information that is not easily inferred from source code: rationale, constraints, and non-obvious workflows. Do not duplicate implementation details, configuration, or command inventories in prose. Keep this file under 100 lines.
- Commit small, complete, meaningful units that leave the application working. Do not split coherent changes or create arbitrary checkpoint commits.
- Review and commit generated assets with their sources when explicitly baking assets; do not regenerate assets during routine verification.

## Game control and iteration

Run the replay suite offscreen and through a private compositor:

```sh
devenv tasks run --show-output hollie:automation-probe
```

Robot discovers journeys under `tools/robot/`; adding a file needs no task
registration. For selected tests, build with `hollie:build-debug`, then use Robot
or Pabot's `--suite`, `--test`, or tag filters in a one-off `devenv shell` command.
Inspect relevant screenshots and runtime logs alongside assertions in the printed
artifact directory. Passing journeys do not prove all gameplay paths or
cross-machine determinism; smoke captures do not prove deterministic replay.

For an ad hoc automated check, put a temporary `.robot` file under `/tmp`,
import `tools/robot/game.resource` by absolute path, and use `Start Journey` /
`Finish Journey` as test setup / teardown. Build with `hollie:build-debug`, then
run it from the project root with a fresh artifact directory, for example:

```sh
devenv shell -- robot --pythonpath tools --outputdir /tmp/hollie-check-results /tmp/hollie-check.robot
```

This uses the same fast GPU sessions without adding to suite discovery. Keep
one-off checks temporary; commit a journey only when it adds lasting regression
coverage. For exploratory commands and observations, use an interactive session:

```sh
devenv shell -- hollie-session
```

Alternatively, `devenv --profile automation up` supervises the same session.
Wait for `Paused control session: /tmp/.../control`, keep the session running,
and use its actual printed directory with `tools/game_control.py`, for example:

```sh
devenv shell -- python3 tools/game_control.py /tmp/.../control '{"op":"step","frames":30,"keys":["S"],"capture":"moved.png"}'
```

Use one controller per session and send commands sequentially. Check response
errors before interpreting results and inspect requested captures. Simulation
stays frozen while a capture finishes; observation does not advance time.
Each step supplies the complete held input snapshot: omitted inputs are released,
and holding an input across steps preserves it. Press edges apply on the first
simulation frame; repeated presses require intervening release ticks.
`Sleep` waits in wall time with simulation frozen; advance gameplay with ticks.
Interactive sessions are paced for observation; automated offscreen journeys
use fixed ticks without real-time pacing. Send `stop` when finished.

Reproduce issues with observations/captures, stop the session, edit, then rebuild
and replay the same inputs and seed. Save lasting regression coverage as Robot
journeys, rather than relying on temporary transcripts. Keep backend
requirements beside tests and share setup/routes through Robot resources.
Use native Robot assertions.

Combine related checks into coherent journeys when they can share a session.
Each journey must start a fresh private game process with sequential commands.
Do not add an implicit gameplay reset: title audio and first-entry checks need
a fresh title-screen start.

Let Pabot schedule independent journeys with bounded parallelism and isolated
sessions, control directories, and artifacts. Tune concurrency using measured
durations and CPU, RAM, and GPU usage. Keep build dependencies and caching in
devenv; execute the shared built binary directly to avoid duplicate build
orchestration and large per-journey snapshots. When changing replay execution,
preserve simulation and animation updates and verify matching observed state
and captured pixels using the same inputs and seed.

Verify fullscreen and resolution changes through headless Gamescope: the user
runs Gamescope with native Wayland clients, and offscreen captures do not exercise
surface size negotiation. Offscreen sessions create no display or window manager;
native presentation uses a private Gamescope compositor. All sessions require GPU
rendering. `HOLLIE_GPU_DEVICE` selects an adapter by name substring;
sessions must fail if it is unavailable or software rendering is detected.

## Casing

- **Ada_Case** for types and enum members.
- **snake_case** for procedures/locals/variables/imports.
- **SCREAMING_SNAKE_CASE** for true constants.
