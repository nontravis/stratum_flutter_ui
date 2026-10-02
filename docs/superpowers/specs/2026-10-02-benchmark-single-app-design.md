# Benchmark in one app run: design

- **Status:** Written 2026-10-02 from the owner's brainstorm rulings; awaiting owner review. Phase 5, task 1, before `perf_freeze` freezes the phase 4 tip.
- **Amends:** `docs/superpowers/specs/2026-10-01-layout-primitives-design.md` section 9 (9.2, 9.4, 9.5). The implementation plan's first step rewrites those subsections from this design.

## 1. Goal

One ABBA comparison of 12 runs takes about 35 minutes, and 70 minutes at the cap of 24 runs (phase 4, 2026-10-02: 36 `flutter drive` invocations of about 54 s each, half of each invocation spent outside the traced windows). The goal is a comparison of 12 runs in about 18 minutes and an escalation of about 9 minutes, with the same precision: the same two-second traces, the same ABBA blocks, and the same verdict rules.

Success: a dry run of one run and a full comparison of 12 runs both finish within 15% of the estimates in section 6, and the verdict code in `perf_abba` passes its existing tests unchanged apart from report keys and folder names.

## 2. Owner rulings (2026-10-02)

| Question | Ruling | Reason |
|---|---|---|
| Keep the full 6 MB timeline per trace? | No. The app summarizes each trace and keeps only the numbers the verdict reads. A `--trace-full <scene>` mode keeps full timelines for one scene when a FAIL needs digging. | The verdict reads summaries only. Full timelines force the 16-trace limit per invocation (layout spec section 12: the binding sends all report data in one message after the last test). |
| Three apps, one per scene group, or one app? | One app with every scene, and a 2 s cool-down after S5 (blur) before the next run. | Saves two builds and the per-group launches. ABBA blocks measure both sides under the same conditions, so a heavy scene's after-effects cancel within the next block. |
| What is one invocation? | One launch of the app runs all 12 runs (or the 12 escalation runs). | Fastest shape. The app's per-trace output reaches the disk before the next trace, so a crash loses only the trace in progress. |
| Does the escalation measure S2-plain? | Yes. The escalation measures the scenes still INCONCLUSIVE after the first 12 runs, plus S2-plain in every run. | The null gate must see the escalation's noise, not only the first 12 runs'. |

Rejected: one-second traces (half the frames, wider intervals, more escalations) and several apps at once (one GPU; macOS slows hidden windows; the S2-plain null gate would fail).

## 3. Design

### 3.1 Run order inside the app

```
build the app once (dart-defines: first run, run count, scene list)
launch the app once
  warm-up: every listed scene once per side, untraced
  for run in first .. first + count - 1:
    print PERF_RUN <run>
    for scene in the listed scenes, in catalog order:
      ABBA block: base 1, cand 1, cand 2, base 2 (each traced)
    after S5: pump 2 s untraced (cool-down)
close the app
```

- The catalog order stays: S2-plain, S1, S1-fast, S2, S2-box, S3, S4, S5. Scene groups (g1 to g3) are removed.
- Each traced step pumps its scene, runs `check`, pumps 250 ms untraced, and traces `drive` for two seconds, as in phase 4.
- The report key becomes `r<run>.<scene>.<side>.<pair>`.

### 3.2 Per-trace summary

- After each trace, the app summarizes the timeline with flutter_driver's `TimelineSummary`, the same code phase 4 ran in the driver, so numbers stay comparable across phases.
- It removes that trace's timeline from the binding's `reportData`, so memory stays flat across 384 traces. `traceTimeline` already clears the VM timeline before each trace (`integration_test/lib/integration_test.dart:302` in the SDK).
- It prints one line: `PERF_SUMMARY ` followed by compact JSON with `key`, `average` (`average_frame_build_time_millis`), `p99Build`, `p99Raster`, and `begins` (each frame's build start in microseconds, relative to the first frame).

### 3.3 Transport to disk

- The example's macOS app runs in the App Sandbox (`com.apple.security.app-sandbox` is true in `DebugProfile.entitlements` and `Release.entitlements`), so the app cannot write under `example/build/`.
- `flutter drive` forwards the app's stdout. `perf_abba` reads the drive process's stdout line by line and, for each `PERF_SUMMARY` line, writes `build/perf/abba/r<run>/<scene>.<side>.<pair>.summary.json` at once.
- On each `PERF_RUN <run>` line, `perf_abba` records `uptime` into `r<run>/load.txt` and the code state into `r<run>/code.txt`.
- A line that does not parse as a complete summary is reported and skipped; its block then misses a trace and is left out, as today.

### 3.4 Checks moved from the driver

- The driver's coverage check (a trace covering less than the two-second window minus two frames throws) moves to `perf_abba`, which reads it from `begins`. A short trace marks its run invalid with the reason `short trace`, next to the existing display-period and lost-frame reasons.
- Phase 4 skipped the remaining groups of an invalid run. With one invocation the app keeps running; an invalid run is left out of the analysis, as today.

### 3.5 Escalation

- `run --from 13 --runs 12` judges runs 1 to 12 from the stored summaries, takes the INCONCLUSIVE scenes, adds S2-plain, and builds the app with that scene list (one build, about 40 s).
- A scene that passed at 12 runs keeps 12 blocks; an escalated scene has 24. The null gate judges S2-plain over all 24 runs.
- The cap of 24 runs and every verdict rule of layout spec section 9.5 stay.

### 3.6 Full-timeline mode

- `run --trace-full <scene> --runs <n>` builds the app with one scene, keeps that scene's full timelines in `reportData`, and the driver writes them as `<key>.timeline.json`.
- `n` is at most 4 (16 traces), the binding's one-message limit. `perf_abba` refuses a larger `n` in this mode. The mode is diagnostic and never enters a verdict.

## 4. Files

All changes sit under `example/`; `lib/` does not change.

| File | Change |
|---|---|
| `integration_test/perf/perf_scene.dart` | `runSteps(scenes, {first, count})`: warm-up once, then one ABBA block per scene per run, and the cool-down after S5. Replaces `abbaSteps`. |
| `integration_test/perf/perf_trace.dart` | New: traces a step, summarizes it, prints the `PERF_SUMMARY` line, and drops the timeline (keeps it in full-timeline mode). |
| `integration_test/layout_perf_test.dart` | Reads `PERF_FROM`, `PERF_RUNS`, `PERF_SCENES`, and `PERF_FULL` from dart-defines and runs `runSteps`. |
| `integration_test/perf/perf_scenes.dart` | One catalog list; `perfGroup` removed. |
| `test_driver/perf_driver.dart` | Writes full timelines only in full-timeline mode; the coverage check moves to `perf_abba`. |
| `tool/perf_abba.dart` | One build and one invocation per call; the stdout reader; per-run folders `r<run>/`; escalation scene selection; `--trace-full`. Verdict code unchanged apart from keys and folders. |
| `test/perf/perf_scene_test.dart`, `test/perf/perf_scenes_test.dart`, `test/tool/perf_abba_test.dart` | Updated and new cases (section 5). |

## 5. Testing

- Run order: warm-up once per scene and side; one ABBA block per scene per run in catalog order; the cool-down only after S5; run numbers start at `first`; a scene list filters the catalog.
- Summary line: encode then parse gives the same values; noise lines in the drive log are ignored; a truncated line is reported and skipped without a crash.
- `perf_abba`: the folder and key changes; the short-trace check; escalation picks the INCONCLUSIVE scenes plus S2-plain; `--trace-full` refuses more than 4 runs; the existing verdict, interval, null-gate, budget, and cap tests pass with the new keys.
- Dry run on the machine: `run --runs 1` finishes in about 1.5 minutes, every summary line parses (none cut by `flutter drive`), and the report has one block per scene, S2-plain included, since S2-plain now runs once per run like every scene.

## 6. Estimates

- Per traced step: about 2.6 s (scene pump, check, 250 ms settle, 2 s trace, summary).
- 12 runs × 8 scenes × 4 traces = 384 traced steps ≈ 16.6 minutes, plus the warm-up (16 untraced drives, about 40 s), one build (about 40 s), one launch (about 10 s), and 11 cool-downs (22 s): about 18 minutes.
- Escalation with 4 inconclusive scenes plus S2-plain: 12 × 5 × 4 = 240 steps ≈ 10.4 minutes plus build and launch: about 11.5 minutes. With fewer inconclusive scenes it is shorter.

## 7. Effect on S2-plain blocks

Phase 4 ran S2-plain in each of three groups, so one run gave 3 S2-plain blocks (36 at 12 runs, 72 at 24). One app runs S2-plain once per run: 12 blocks at 12 runs, 24 at 24. The null gate's interval therefore widens (phase 4 resolution: ±4.3% at 36 blocks, ±1.5% at 72), and the gate catches less machine noise. Scene verdicts do not change, because each scene is judged on its own blocks. This is the price of the one-app ruling. If the first phase 5 comparison shows a resolution too coarse to trust, S2-plain can run three times per run: 2 extra blocks × 4 traces × 2.6 s ≈ 21 s per run, about 4 minutes per 12-run comparison. The owner decides after that comparison.

## 8. Risks checked by the plan

- `flutter drive` must forward a summary line of about 2 KB uncut. If it cuts lines, the app computes the display period, frame count, and span itself and prints only those numbers.
- flutter_driver's `timeline_summary.dart` imports `package:file` and flutter_driver's `common.dart`; the plan confirms the integration-test target compiles with that import on macOS.
- A hidden window during a long single invocation invalidates every run it overlaps. The report names those runs; `run --from` re-runs them only within the cap.

## 9. Out of scope

Verdict rules, the scene catalog, semantics in scenes, iOS and Android runs, and several apps at once.
