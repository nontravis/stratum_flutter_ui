---
name: project-vm-vs-chrome-geometry
description: VM widget tests lay out text taller than Chrome, so a focus or scroll bug that depends on geometry may not reproduce at the same key count
metadata:
  type: project
verified: 2026-10-02
---

On 2026-10-02 the web focus RCA (Tab landing on the page's ScrollFocus stop after arrow scrolling) did not reproduce in the VM at the reported Down x3. It did reproduce at Down x4. The flutter_test font wraps the demo's intro text onto more lines, so row 1 sat at y=176 in the VM against an estimated y=136 on Chrome.

**Why:** Flutter's ReadingOrderTraversalPolicy orders Tab stops by unclipped rects. The trigger is geometric (the row lies wholly above the viewport's top edge), so any font difference shifts the trigger to a different key count.

**How to apply:** when a focus, traversal, or scroll RCA depends on positions, drive the probe until the geometric condition holds (for example, scroll until the row's bottom is above the viewport's top). Log the rects, and do not trust the user's key count. Give main a release-safe Chrome probe page: FocusNode.debugLabel is null in release, so name nodes by identity. Findings: `.superpowers/p4-followups/rca-web-focus.md`. Related: [[project-benchmark-noise]].
