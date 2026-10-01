---
name: project-benchmark-noise
description: macOS profile benchmark on the owner's shared Mac is noise-dominated for sub-ms avg build; how to tell noise from a code regression
metadata:
  type: project
verified: 2026-10-01
---

On 2026-10-01 the phase 3 S4 "regression" (+45.72% avg build, Task 10) turned out to have no code cause. The new and old code paths matched exactly on rebuild counts and render/layer trees, and an in-process ABBA A/B came out at -10.1%.

**Why:** the Mac (8 performance + 4 efficiency cores) runs other agent sessions, with load average 9 to 27. Per-run noise on identical code (S2-plain) is about ±50% for averages of 0.2 to 0.4 ms. Slow windows are bursty, last about 0.5 s, and scale every phase evenly, including COMPOSITING and the raster thread's LayerTree::Paint.

**How to apply:** when a benchmark scene fails, first split the stored `example/build/perf/abba/r*g*/<scene>.<side>.<pair>.timeline.json` into per-phase means. If engine and raster phases rise as much as BUILD, suspect the environment. A trace with far fewer than about 289 frames in its two-second window lost frames (hidden test window or a starved machine, seen at load 12 to 35 on 2026-10-01); `perf_abba` leaves that whole run out. The benchmark itself compares in one process (spec section 9 of `docs/superpowers/specs/2026-10-01-layout-primitives-design.md`, tools `example/tool/perf_freeze.dart` and `example/tool/perf_abba.dart`), and its S2-plain null control shows each invocation's noise. See [[stratum-layout-primitives]].
