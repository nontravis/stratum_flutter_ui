---
name: stratum-flutter-ui
description: Use when building or changing a Flutter app on Stratum UI (screen, layout, taps, hover, keyboard and focus, theme, app start, or any Stratum* widget). Layout triggers are *Layout primitives (ColumnLayout, ContainerLayout.builder), showModalLayout, reorderable lists, and Space spacing. Interaction triggers are Interaction, HoverBuilder, FocusBuilder, and focus rings (StratumFocusBorder). Theme triggers are StratumThemeController install and switching, StratumThemeApplication, remote and preloaded themes, StratumSplashScreen, theme.yaml tokens (border, shadow, blur), and context.* reads (context.themeData, KeyboardVisibilityScope.setVisibleForTesting). Widget triggers are StratumWebView, StratumWebZoom, page transitions (StratumTransitionPage), StratumCaret, named colors (ColorEnum), Thai labels and supportedLocales, Show and disabled dimming, StratumPlaceholderPage, and update prompts (StratumUpdateGate, UpdateChecker).
---

# Stratum Flutter UI

Every screen and component in an app that depends on `stratum_ui` builds on this layout family. Each primitive styles
its own box (`style: WidgetStyle`), takes one interaction (`interaction: Interaction`) for taps, hover, and
shortcuts, and scrolls through one `scroll: Scroll` model — never a raw `Container`, `Column`, `Row`, or
`ListView`. Import the barrel: `package:stratum_ui/src/src.dart`.

Names: screen-building blocks carry no `Stratum` prefix (`Interaction`, `Scroll`, `TapTargetSize`, `FocusGroup`,
`ReorderableItemsController`, `Show`, `ShowTransition`, `ShowSlideDirection`), while design-drawn components and theme
or app-setup types keep it (`StratumSlot`, `StratumHighContrastMode`). The old names `StratumInteraction`,
`StratumScroll`, `StratumTapTargetSize`, `StratumFocusGroup`, `StratumReorderableItemsController`, `StratumShow`,
`StratumShowTransition`, `StratumShowSlideDirection`, `Slot`, and `HighContrastMode` are gone: write the new names.
`FocusSpread` (use `StratumFocusBorder`, its color as `customStyle: StratumFocusBorderStyle(color: ...)`) and
`resolveSize` (use `resolveDefaultSize`) are gone too.

## Need X, open reference Y

Open only the reference your task needs.

| Need | Open |
|------|------|
| Install, App assembly, Widget settings, System bars | [references/setup.md](references/setup.md) |
| Themes: fonts, Material text theme, Custom text size, theme models, controller and preload, splash screen, remote theme zips, disabled opacity, border, shadow, and blur tokens, System bar look, Focus ring look, app-wide component defaults | [references/theme.md](references/theme.md) |
| Values, Page transitions | [references/style.md](references/style.md) |
| Screen corner radius, Keyboard visibility | [references/responsive.md](references/responsive.md) |
| Box layouts, Scroll views, Spacing, Focus ring, `StratumInkWell` tap surface with its ids and screen-reader actions, Show and hide, Modal layout, Split layout, Page layout, Hover and focus observers | [references/layout.md](references/layout.md) |
| Utilities (CO-01): Slot, Web view, Caret, Web zoom | [references/utility.md](references/utility.md) |
| Built-in labels: Thai labels and supportedLocales | [references/accessibility.md](references/accessibility.md) |
| Disabled components, Named colors | [references/customize.md](references/customize.md) |
| Control components (CO-02) | [references/control.md](references/control.md) |
| Disclosure components (CO-03) | [references/disclosure.md](references/disclosure.md) |
| Display components (CO-04) | [references/display.md](references/display.md) |
| Feedback components (CO-05): Toast (Notices), Placeholder page, Update gate | [references/feedback.md](references/feedback.md) |
| Form components (CO-06) | [references/form.md](references/form.md) |
| Navigation components (CO-07) | [references/navigation.md](references/navigation.md) |
| Overlay components (CO-08) | [references/overlay.md](references/overlay.md) |

## Component index

### Utilities (CO-01): [references/utility.md](references/utility.md)

| CO id    | Name     | Status |
|----------|----------|--------|
| CO-01-01 | Slot     | built  |
| CO-01-02 | Web view | built  |
| CO-01-03 | Caret    | built  |
| CO-01-04 | Web zoom | built  |

### Control (CO-02): [references/control.md](references/control.md)

| CO id    | Name             | Status                              |
|----------|------------------|-------------------------------------|
| CO-02-01 | Audio player     | planned (stratum-control-composite) |
| CO-02-02 | Button           | planned (stratum-control-base)      |
| CO-02-02 | SearchButton     | planned (stratum-control-composite) |
| CO-02-02 | InfoButton       | planned (stratum-control-composite) |
| CO-02-02 | MoreButton       | planned (stratum-control-composite) |
| CO-02-03 | Chat             | planned (stratum-control-composite) |
| CO-02-04 | Checkbox         | planned (stratum-control-base)      |
| CO-02-05 | Color picker     | planned (stratum-control-composite) |
| CO-02-06 | Comment          | planned (stratum-control-composite) |
| CO-02-07 | Link             | planned (stratum-control-base)      |
| CO-02-08 | Menu             | planned (stratum-control-composite) |
| CO-02-09 | Radio            | planned (stratum-control-base)      |
| CO-02-10 | Rating           | planned (stratum-control-base)      |
| CO-02-11 | Scrollbar        | planned (stratum-control-base)      |
| CO-02-12 | Slider and range | planned (stratum-control-composite) |
| CO-02-13 | Toggle           | planned (stratum-control-base)      |
| CO-02-14 | Video player     | planned (stratum-control-composite) |

### Disclosure (CO-03): [references/disclosure.md](references/disclosure.md)

| CO id    | Name      | Status                       |
|----------|-----------|------------------------------|
| CO-03-01 | Accordion | planned (stratum-disclosure) |

### Display (CO-04): [references/display.md](references/display.md)

| CO id    | Name                        | Status                              |
|----------|-----------------------------|-------------------------------------|
| CO-04-01 | Avatar                      | planned (stratum-display-base)      |
| CO-04-02 | Avatar group                | planned (stratum-display-composite) |
| CO-04-03 | Badge and tag               | planned (stratum-display-base)      |
| CO-04-04 | Chart and graph             | planned (stratum-display-composite) |
| CO-04-05 | Code snippet                | planned (stratum-display-composite) |
| CO-04-06 | Divider                     | planned (stratum-display-base)      |
| CO-04-07 | File                        | planned (stratum-display-composite) |
| CO-04-08 | Icon and logo               | planned (stratum-display-base)      |
| CO-04-09 | Illustration                | planned (stratum-display-base)      |
| CO-04-10 | Image and video placeholder | planned (stratum-display-composite) |
| CO-04-11 | Shortcut                    | planned (stratum-display-base)      |
| CO-04-12 | Step                        | planned (stratum-display-composite) |
| CO-04-13 | Table                       | planned (stratum-display-composite) |

### Feedback (CO-05): [references/feedback.md](references/feedback.md)

| CO id    | Name             | Status                                           |
|----------|------------------|--------------------------------------------------|
| CO-05-01 | Alert            | planned (stratum-feedback-composite)             |
| CO-05-02 | Callout          | planned (stratum-feedback-composite)             |
| CO-05-03 | Loading          | planned (stratum-feedback-base)                  |
| CO-05-04 | Modal            | planned (stratum-feedback-composite)             |
| CO-05-05 | Marketing modal  | planned (stratum-feedback-composite)             |
| CO-05-06 | State            | planned (stratum-feedback-composite)             |
| CO-05-07 | Toast            | built, look pending (stratum-feedback-composite) |
| CO-05-08 | Placeholder page | built                                            |
| CO-05-09 | Update gate      | built                                            |

### Form (CO-06): [references/form.md](references/form.md)

| CO id    | Name                    | Status                           |
|----------|-------------------------|----------------------------------|
| CO-06-01 | Combobox                | planned (stratum-form-base)      |
| CO-06-02 | Date input and calendar | planned (stratum-form-base)      |
| CO-06-03 | Dropdown                | planned (stratum-form-base)      |
| CO-06-04 | Editable text           | planned (stratum-form-base)      |
| CO-06-05 | File uploader           | planned (stratum-form-base)      |
| CO-06-06 | Number input            | planned (stratum-form-base)      |
| CO-06-07 | Rich text editor        | planned (stratum-form-base)      |
| CO-06-08 | Stepper                 | planned (stratum-form-base)      |
| CO-06-09 | Text area               | planned (stratum-form-base)      |
| CO-06-10 | Text input              | planned (stratum-form-base)      |
| CO-06-11 | Time input              | planned (stratum-form-composite) |

### Navigation (CO-07): [references/navigation.md](references/navigation.md)

| CO id    | Name                      | Status                                 |
|----------|---------------------------|----------------------------------------|
| CO-07-01 | Breadcrumb                | planned (stratum-navigation-base)      |
| CO-07-02 | Side navigation           | planned (stratum-navigation-composite) |
| CO-07-03 | Top and bottom navigation | planned (stratum-navigation-base)      |
| CO-07-03 | TopNavigation             | planned (stratum-navigation-composite) |
| CO-07-04 | Pagination                | planned (stratum-navigation-base)      |
| CO-07-05 | Horizontal tabs           | planned (stratum-navigation-base)      |
| CO-07-06 | Vertical tabs             | planned (stratum-navigation-base)      |
| CO-07-07 | Tree view                 | planned (stratum-navigation-base)      |

### Overlay (CO-08): [references/overlay.md](references/overlay.md)

| CO id    | Name                | Status                              |
|----------|---------------------|-------------------------------------|
| CO-08-01 | Tooltip             | planned (stratum-overlay-base)      |
| CO-08-02 | Popover             | planned (stratum-overlay-base)      |
| CO-08-03 | BaseTutorialPopOver | planned (stratum-overlay-base)      |
| CO-08-03 | Tutorial            | planned (stratum-overlay-composite) |
| CO-08-03 | TutorialContainer   | planned (stratum-overlay-composite) |

### Ruled out

Figma pages that no phase builds.

| CO id | Name              | Status    |
|-------|-------------------|-----------|
| —     | Platform native   | ruled out |
| —     | Handoff & Helpers | ruled out |
| —     | Embeds & Widgets  | ruled out |
| —     | Cursor            | ruled out |
| —     | Colors _Swatch    | ruled out |
| —     | .utilities        | ruled out |

## Planned or missing components

- **A `planned (<phase slug>)` component you need now**: build a temporary widget in the app from `*Layout`
  primitives, `WidgetStyle`, theme tokens, and `StratumInkWell`, with no `Stratum` prefix. A name Flutter already uses
  (`Checkbox`, `Divider`, `Slider`, `Tooltip`) takes your app's own prefix or suffix, for example AppCheckbox, so it never
  clashes with `package:flutter/material.dart`. Tag it with the comment
  `// STRATUM-PENDING: <CO id> <Name>`, for example `// STRATUM-PENDING: CO-02-02 Button`. When the component ships,
  grep the tag and swap in the Stratum widget.
- **A component Stratum lacks** (absent from the index, or `ruled out`): build it as a permanent component of the app,
  under the same build rules and with no `Stratum` prefix; a name Flutter already uses takes your app's own prefix or
  suffix, as above. It takes no tag, and Stratum gets no request for it.
