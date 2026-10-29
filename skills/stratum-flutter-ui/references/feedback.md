# Feedback (CO-05)

## Toast (CO-05-07)

**When to use and not:** Show a short notice from one call, as a float toast in a screen corner or a solid snackbar
along a screen edge, above every route; never make its action the only way to do that action.

**Short example:** Place one host, then call `context.showToast(message: 'Saved')` from any context below it.

- Under `StratumApplication`, pass `noticeHost:` to customize the host, or keep `notices: true`, instead of placing
  one yourself (see App assembly).
- **`StratumToastHost`** — place it once in `MaterialApp.builder`, below `StratumThemeApplication` and above the app's
  navigator, so every notice shows above every route, modal routes included. It wraps `toastification` itself: call
  `context.showToast(...)`, never `toastification.show`, since a raw call can freeze the wrong per-alignment config.
  An app that already wraps its root in its own `ToastificationWrapper` keeps it; the host adds none. One solid notice
  shows at a time (further ones queue in call order), and float notices stack up to 3 per corner, the newest nearest
  the screen edge; a fourth closes that corner's oldest.

  ```dart
  MaterialApp(
    builder: (context, child) => StratumThemeApplication(
      themes: themes,
      themeMode: ThemeMode.system,
      child: StratumToastHost(child: child!),
    ),
    home: HomePage(),
  );
  ```

**Key props:** On the call, `message` (required), `kind`, `action`, `placement`, and `customStyle`.

- **`context.showToast`** — shows one notice from any context under the host: `message` (required), `kind`
  (`FeedbackState.info`, the default, `.positive`, `.warning`, `.negative`), `action` (a `StratumToastAction` of label
  and callback), and `placement`. A call with no host above throws a `FlutterError` naming `StratumToastHost`.
- **`context.dismissAllToasts()`** — closes every notice at once, float and solid, and empties the solid queue, so no
  waiting notice shows later; it does nothing while none shows or waits, runs no exit animation under reduced motion,
  and returns focus from a notice that held it. Call it on logout and on account switch, as
  `ScaffoldMessenger.clearSnackBars()` serves snack bars, so a notice from the ended session never reaches the next
  one.

  ```dart
  Future<void> logOut(BuildContext context) async {
    context.dismissAllToasts();
    await auth.signOut();
  }
  ```

**Variants:** Float or solid placement, four kinds, and the plain look or the app's own.

- **`StratumToastPlacement`** — `const StratumToastPlacement.float(StratumToastCorner.bottomEnd)` for a corner
  (`topStart` … `bottomEnd`, start and end following the text direction), or
  `const StratumToastPlacement.solid(StratumToastEdge.top)` for a full-width bar at an edge. Omitted placement defaults
  by window size: bottom center on mobile and tablet, bottom start on desktop.
- The plain look draws every value from theme tokens, each kind with its own icon as well as color; a float notice's
  corner next to a rounded screen corner follows the screen's curve. Pass
  `StratumToastHost(builder: (context, notice) => ...)` for your own look instead; placement, timing, and the
  announcement stay the host's. A solid notice's plain-look fill declares itself under the status bar or home
  indicator, as a page layout's fills do, so the bar icons stay readable over it; your own look declares its own
  fill. `customStyle` on the call wins over the theme and the app-wide notice style, field by field.

**Slots:** `builder` on the host replaces the look of every notice.

- **Your `builder` look** — the host gives it the notice's full slot: the theme's notice width, capped by the window,
  in its corner, so draw at that width and never place or size the notice yourself. From the `StratumToastNotice`,
  pad your content by `notice.insets` (a solid notice's status bar or home indicator; zero on a float), close through
  `notice.close()` from your close button and after your action's callback, so the queue, the focus return, and the
  timers stay right, and label the close button with `notice.closeLabel` and the kind's icon with
  `notice.kindLabel`, the same names the announcement speaks. Merge `notice.pageSnack` then `notice.customStyle` over
  your own style to keep the style order.

**Responsive props:** An omitted `placement` follows the window size, and the notice width is capped by the window (see
Variants and Slots).

**Accessibility:** Each notice announces once, closes by swipe, button, or Esc, and pauses while hovered, focused, or
touched.

- A notice closes after 4 s, or 8 s with `action: StratumToastAction(label: 'Undo', onPressed: undo)`; hover, focus,
  and touch pause it, and a notice with an action never closes by itself while a screen reader runs. A swipe, the
  close button, or Esc while focus is inside it closes a notice; a tap on the action runs its callback, then closes
  it. Each notice announces once on show, the kind's name then the message, taking no focus.
- **`StratumToastHost(closeButtonLabel:, kindLabels:)`** — replace the built-in close-button label and, per
  `FeedbackState`, the kind's name; each reaches the announcement and the accessible names alike, and a kind missing
  from `kindLabels` keeps its built-in name.
- **`StratumToastHost(focusShortcuts:, focusShortcutHint:)`** — a host shortcut moves focus into the newest notice on
  screen from any page or dialog, to its action, else its close button; it does nothing while no notice shows.
  Platform-ordered by default: Option+T then F8 on macOS and iOS, since F8 is a media key there, and F8 then Alt+T
  elsewhere. Pass your own `focusShortcuts` to replace the keys, `const []` to turn the shortcut off, and
  `focusShortcutHint` to replace the announcement's hint, which otherwise names the first key; the hint speaks on
  desktop and web only.
- A notice's action is never the only way to do that action: offer it in your own page too, as Gmail offers undo on
  its `z` key beside the notice's Undo, since a notice can close, or sit under a pushed route, before the end user
  reaches it.

**Related:** App assembly in [setup.md](setup.md) passes `noticeHost:`. The Figma Toast look is planned in
`stratum-feedback-composite`.

**Catalog path:** —

## Placeholder page (CO-05-08)

**When to use and not:** Fill the body of a page whose screen is not built yet; the app's own page and navigation keep
the app bar and the back action.

- **`StratumPlaceholderPage`** — put `StratumPlaceholderPage()` in the body of a page whose screen is not built yet.
  It fills the space it gets and shows the built-in title "Coming soon" (Thai "เร็วๆ นี้" for a Thai locale), centered.
  `title` replaces that title, also for screen readers; `message` adds centered text below it; `icon` adds an icon
  above it, sized 48 in the theme's secondary icon color and skipped by screen readers. The title reads as a heading.
  It adds no app bar or back button: the app's own page and navigation carry them. Text wraps, and the page scrolls
  when it is taller than its space.

**Short example:** `StratumPlaceholderPage(message: 'Coming in the next release.', icon: Icon(Icons.construction))`

**Key props:** `title` (null keeps the built-in title; an empty string shows as given) and `message` (null shows none).

**Variants:** —

**Slots:** `icon`: any widget, laid out at the page's icon size whatever size it asks for; an icon with its own `color`
keeps it.

**Responsive props:** —

**Accessibility:** The title reads as a heading and the icon is skipped; the icon keeps its size at any text scale while
the text wraps and the page scrolls.

**Related:** Slot (CO-01-01) marks one place inside a layout instead of a whole screen.

**Catalog path:** —

## Update gate (CO-05-09)

**When to use and not:** Gate the app on its own update check: a required update or maintenance replaces every page, an
optional update opens the app's dialog over them. It draws nothing and calls no store.

**Short example:** Pass `updateGate:` to `StratumApplication`, or place the gate yourself in `MaterialApp.builder`.

- Under `StratumApplication`, pass `updateGate: (child) => StratumUpdateGate(..., child: child)` instead of placing
  the gate yourself (see App assembly).
- **`StratumUpdateGate`** — wrap the app's navigator in `MaterialApp.builder`, below `StratumThemeApplication`, so the
  gate covers every route. It asks your `UpdateChecker` and draws nothing itself: `builder` returns your own screen
  for each `UpdateGateState`.

  ```dart
  MaterialApp(
    builder: (context, child) => StratumThemeApplication(
      themes: themes,
      themeMode: ThemeMode.system,
      child: StratumUpdateGate(
        checker: AppUpdateChecker(),
        builder: (context, gate) => switch (gate) {
          UpdateGateRequired() => const ForceUpdateScreen(),
          UpdateGateMaintenance(:final retry, :final checking) =>
            MaintenanceScreen(onRetry: checking ? null : retry),
          UpdateGateAvailable(:final dismiss, :final checking) =>
            UpdateDialog(onLater: dismiss, busy: checking),
        },
        child: child!,
      ),
    ),
  );
  ```

**Key props:** `checker` (the app's `UpdateChecker`), `builder` (the app's screen or dialog for each `UpdateGateState`),
and `child` (the app's navigator), all required.

- **`UpdateChecker`** — implement `Future<UpdateStatus> check()`: read your remote settings, package version, and
  store version, and answer `UpdateStatus.upToDate`, `.available`, `.required`, or `.maintenance`. The package calls
  no store, plugin, or backend. A thrown error shows the app, never a lockout; log it in your checker. The gate asks
  when it mounts, on each return to the foreground, and on `retry`, one ask at a time, and sets no time limit: give
  `check` your own timeout.

**Variants:** `UpdateGateRequired` and `UpdateGateMaintenance` replace the navigator; `UpdateGateAvailable` opens a
dialog over it.

- **Full screens** — `UpdateGateRequired` (no way on) and `UpdateGateMaintenance` (call `retry`) replace the
  navigator, so the app's pages start over from the first page once the gate shows the app again; screens swap with
  no animation. While a later ask runs, the gate keeps the shown screen and sets `checking`: show a busy cue and
  disable retry, since a retry during an ask does nothing. Your update button runs your own store or installer code;
  the gate takes no update callback. Each screen opens as a screen of its own: focus moves in, and a screen reader
  announces it. A tooltip or a text field works on it, since it sits in an overlay of the gate's own. No navigator
  exists while a full screen shows: build it without routes or dialogs of its own, and guard any global
  `navigatorKey` use, such as from a push-notification handler, against a null `currentState`.
- **The update dialog** — `UpdateGateAvailable` opens your dialog once per gate lifetime, as a route on your app's
  navigator over the page it shows; a new launch may offer it again, since the package stores nothing. Draw its scrim
  and card yourself: the route paints nothing and runs no transition. While it shows, taps, focus, and screen readers
  stay away from the pages behind it, focus moves into it, and Tab stays inside it. The Android back button closes the
  dialog alone, so the user stays on the page they were on, and Esc calls `dismiss`. Call `dismiss` from your later
  button, and from a scrim tap if you want one. A later ask that answers anything but `available` — up to date,
  required, maintenance, or a failure — closes it first. The gate needs a navigator below it, as `MaterialApp.builder`
  gives.

**Slots:** `builder` returns every screen and dialog; the gate draws none of its own.

**Responsive props:** —

**Accessibility:** Each full screen takes focus and a screen reader announces it; the dialog holds focus and Tab, the
Android back button closes it, and Esc calls `dismiss`.

**Related:** App assembly in [setup.md](setup.md) passes `updateGate:`.

**Catalog path:** —

## Planned

Not built yet. To use one now, follow Planned or missing components in [SKILL.md](../SKILL.md).

- CO-05-01 Alert: planned (stratum-feedback-composite)
- CO-05-02 Callout: planned (stratum-feedback-composite)
- CO-05-03 Loading: planned (stratum-feedback-base)
- CO-05-04 Modal: planned (stratum-feedback-composite)
- CO-05-05 Marketing modal: planned (stratum-feedback-composite)
- CO-05-06 State: planned (stratum-feedback-composite)
