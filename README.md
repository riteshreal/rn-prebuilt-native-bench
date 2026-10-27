# prebuilt-native-bench

How much faster is a **cold** Android build when the native libraries (Kotlin + C++) of
[react-native-mmkv](https://github.com/mrousavy/react-native-mmkv),
[react-native-vision-camera](https://github.com/mrousavy/react-native-vision-camera) and
[nitro](https://github.com/mrousavy/nitro) are consumed as prebuilt AARs instead of compiled from source?

## What is measured

`:app:assembleDebug`, arm64-v8a, of the mmkv example app and the VisionCamera `simple-camera` app, in two modes:

| mode | what happens |
| --- | --- |
| `source` | every library is compiled from source (Kotlin + CMake/Ninja) |
| `prebuilt` | `react-native-nitro-modules`, `react-native-mmkv` and the VisionCamera modules are resolved as AARs (classes + `.so` + prefab) from a local Maven repo |

Third-party libraries (Skia, Reanimated, Worklets, ...) stay on source in both modes.

"Cold" means that before every timed run: the experiment's Gradle daemons are stopped, everything in the
Gradle user home except the downloaded-dependency store is deleted (no build cache, transforms, kotlin-dsl,
file hashes), and every `build/`, `.cxx/` and `.gradle/` directory of the app and its libraries is deleted.
`--no-build-cache --no-configuration-cache`, Kotlin compiled in-process, no ccache.
Runs are interleaved (source, prebuilt, source, ...) to cancel out machine drift.

Nothing in the upstream repos is modified: `exp/init/exp.init.gradle` publishes the AARs and swaps
`project(':lib')` for the AAR via dependency substitution.

## Run it

GitHub Actions: *Actions -> prebuilt-native-bench -> Run workflow* (inputs: runner label, app `mmkv` or `vc`).
Every timed build runs on its own runner, in parallel:

| job | what it does |
| --- | --- |
| `prebuild` | `ci-prebuild.sh`: dependency warm-up, then compile + publish the AARs (checks each AAR ships only its own `.so`); caches the dependency store, uploads the AARs |
| `timed` x4 | `ci-timed.sh`: mode `source`/`prebuilt` x rep 1/2, one cold build each, from the restored dependency store |
| `report` | `ci-report.sh`: merges the rows, prints the comparison, fails if a run failed or a mode is missing results |

Runs land on different machines of the same model, so the spread between the two reps of a mode is the noise to read the gap against.

Any single Mac with JDK 17, Node, Bun and the Android SDK (NDK `29.0.14206865`, CMake `3.22.1`) can run everything back to back, interleaved on one machine:

```bash
./run-ci.sh mmkv 3
./run-ci.sh vc 3
```

Results land in `exp/results/` (`summary.csv`, per-run Gradle logs, per-task timings, `<app>.report.txt`).
