---
name: reference-breakpoint-source-access
description: use when researching responsive breakpoints or device sizes; lists machine-readable endpoints and access workarounds for M3, Apple HIG, Android, StatCounter
metadata:
  type: reference
verified: 2026-09-29
---

**Pointer:**
- Material 3 Breakpoints page (formerly window size classes) is a JS app. curl and WebFetch get HTTP 404. To render it, use `https://r.jina.ai/https://m3.material.io/foundations/layout/applying-layout/window-size-classes`.
- Apple HIG as JSON: `https://developer.apple.com/tutorials/data/design/human-interface-guidelines/layout.json`. The 2026-09-09 revision removed the device-size and size-class tables. The last full copy is `https://web.archive.org/web/20260702060104id_/<same json URL>`. The body is gzip-compressed, so run `gunzip` on it.
- Android breakpoint constants: androidx `window/window-core/.../layout/WindowSizeClass.kt` (raw GitHub, branch androidx-main).
- StatCounter CSV: `gs.statcounter.com/chart.php?device=Desktop&device_hidden=desktop&statType_hidden=resolution&region_hidden=ww&granularity=monthly&statType=Screen%20Resolution&region=Worldwide&fromInt=YYYYMM&toInt=YYYYMM&fromMonthYear=YYYY-MM&toMonthYear=YYYY-MM&csv=1`
- Measured phone and foldable viewports: DeviceAtlas blog "Viewport, Resolution, Diagonal Screen Size, and DPI for the Most Popular Smartphones" (May 2026 data).
- Flutter package source: `https://pub.dev/api/packages/<name>` gives the `archive_url` of the published tarball.

**Purpose:** Primary sources with line-quotable copies, used for the stratum_ui `WindowSize` breakpoint study on 2026-09-29. The full findings are in `tmp/stratum-ui-dispatch/breakpoint-research.findings.md` under the NTD OS root.

**Use when:** You need breakpoint values, device logical sizes, or desktop resolution share for this project again.
