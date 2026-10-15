# Robot pilot decision record

The pilot supports using Robot for authored journeys, subject to reviewing the
authoring experience before migrating anything further. It remains alongside
the existing JSON runner. The performance evidence does not justify a Rust RPC
service: both runners already use Python, and simulation/rendering remain in
the same Rust executable.

Measurements below were taken on 15 October 2026 with Python 3.14.7, Robot
Framework 7.4.2 from the locked Nix package set, Linux 6.18.54, a Ryzen 7 7800X3D,
and an RX 9070 XT using RADV/Vulkan. The game used the debug profile with
application optimization level 1 and dependency optimization level 3, built
from `ac9a44c3be41f9e0c64230aff8c355fe817e87f7`. Its SHA-256 was
`0288245c35d39a3a5d7e79267037ab925ed46654401209fccd89f7b2659ae22a`.

Each journey/runner combination received one excluded warm-up, three measured
fresh-display runs, and seven measured recorded-response runs after another
excluded warm-up. Runner order alternated. Live runs were serial, with no
concurrent builds/checks. Movement and riding used the existing offscreen GPU
path on a private Xvfb display; display transitions used native Wayland under
headless Gamescope at 3840×2160. The existing systemd game was left running;
background device contention was not controlled.

The live comparison includes the same complete command snapshots, seeds,
press/release edges, fixed tick batches, frozen-time sleeps, observations,
captures and validation workload. Both runners used the existing client and
its 20 ms mailbox polling interval. JSON retained its normal transcript output;
Robot produced XML and HTML reports. Both also wrote benchmark instrumentation.
Robot assertions occur beside their actions; JSON assertions remain at the end.

Runner elapsed time below includes framework import, execution, capture copying,
validation, evidence output and report generation. It excludes display/game
startup and shutdown. Values are median seconds, with measured min–max.

| Live journey | JSON | Robot |
| --- | --- | --- |
| Movement | 4.845 (4.830–4.873) | 5.008 (4.951–5.085) |
| Riding | 27.846 (27.846–27.878) | 27.915 (27.913–27.966) |
| Native 4K transitions | 4.762 (4.754–4.769) | 4.867 (4.850–4.879) |

Fresh-process wall-time medians, including startup and shutdown, were respectively
6.272/6.472, 29.250/29.351 and 6.172/6.422 seconds for JSON/Robot. The parent's
bounded subprocess wait introduces up to roughly 50 ms of observation granularity;
the inner runner timers avoid that effect. Startup medians were 1.052/1.048 seconds
across the measured JSON/Robot live runs. Robot import and HTML generation medians
were 73 ms and 8 ms; XML generation is included in execution time.

The recorded-response comparison removes the game, GPU, compositor and mailbox
waits. It still runs actual assertions, capture copying, ImageMagick checks,
frozen-time sleeps and report generation against the same saved responses and
images. It is a harness comparison, not a simulation-performance benchmark.

| Recorded-response journey | JSON | Robot | Difference of medians |
| --- | --- | --- | --- |
| Movement | 1.506 (1.482–1.511) | 1.611 (1.574–1.614) | +105 ms |
| Riding | 0.917 (0.903–0.923) | 1.015 (1.007–1.019) | +98 ms |
| Native 4K transitions | 0.856 (0.851–0.870) | 0.962 (0.956–0.967) | +106 ms |

Median aggregate live command latency was 3.346/3.364 seconds for movement,
26.883/26.822 for riding, and 3.849/3.848 for display transitions. The small
differences vary in direction; they do not demonstrate faster game execution.
Three live repetitions are insufficient to establish small performance effects,
and these results do not predict other hardware or much larger suites.

All 12 live pairs matched the original JSON command trace exactly and returned
identical states/errors at every command. Assertion-kind counts matched the
baseline in each case. All 60 corresponding cross-runner captures matched with
ImageMagick AE=0, in addition to the scenarios' own replay comparisons and extent
checks. The 4K round trip produced 3840×2160, then 1280×720, then 3840×2160.
All recorded-response runs also passed trace/state/coverage comparison. Six
deliberate failures proved that both runners reject a changed command, a changed
state and mismatched pixels while retaining diagnostics. This is equivalence
evidence on this machine, not a cross-machine visual golden test.

Full per-command timings, transcripts, renderer reports, screenshots, diffs,
framework reports and failure artifacts are retained at
`/tmp/hollie-robot-benchmark-cae8ojma/results.json` and its referenced directories.
The opt-in benchmark task reproduces the experiment; it is intentionally absent
from routine commit verification. The hook performs Robot's dry run instead.

The maintenance cost is one Nix-provided Python package, a small game-keyword
library, and intentionally duplicated pilot journeys while the decision is open.
The benchmark instrumentation is separate from normal JSON execution. Riding
demonstrates native Robot resource reuse without hiding tick boundaries or
turning every analog sample into prose. A migration should consolidate shared
game assertions/capture helpers rather than permanently maintain two copies.
No additional RPC service or per-tick Python stepping is needed.

The implementation follows Robot's
[Python library and resource model](https://robotframework.org/robotframework/7.4.2/RobotFrameworkUserGuide.html).
[RobotCode](https://robotcode.io/01_about/) is an optional editor/debugging choice;
it is not a runtime dependency and its editor integration was not exercised by
this benchmark. Conditional tick waits and the remaining journeys are outside
this pilot.
