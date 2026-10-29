# Theme

Sections: Themes; Theme font files; Default theme fonts; Google font weights; Material text theme; Custom text size;
Theme models; Before `preload`; `StratumThemeController`; `StratumThemeApplication.controlled`; `StratumThemePreloader`;
`StratumSplashScreen`; Remote theme zips; Pack and check a theme zip; Supported zip tools; Disabled opacity and scrim;
Border, shadow, and blur tokens; System bar look; Focus ring look; App-wide component defaults

## Themes

- **Theme font files** — a theme ships its own fonts by listing them under `typography.fonts.<key>.files` in its
  `theme.yaml`: paths relative to that file's folder, ending in `ttf` or `otf` (`files: [fonts/Brand-Regular.ttf]`).
  Declare the font folder in pubspec (`- assets/themes/brand/fonts/`), since Flutter does not include asset
  subfolders. A font with `files` takes no `package` and no `Google/` family. Each theme's fonts register under
  `<theme id>/<family>`, so two themes may ship files under the same family name; a theme that inherits the font
  from a layer it merges over shares that layer's registration.
- **Default theme fonts** — the package default theme names Google fonts only (`Google/Inter`, `Google/Geist`,
  `Google/Geist Mono`, `Google/Roboto Mono`, `Google/Kanit`) and bundles no font file. The app owns
  `GoogleFonts.config`: bundle the font files under its own assets to skip the download, which also keeps the app's
  widget tests off the network, since the google_fonts library looks in the assets first.
- **Google font weights** — a Google font draws only in the weights its theme loads it in: each type's `weight` for
  the font that type names, and every type's weight for each tag's `body` font and theme-wide `mono`. A recipe weight
  outside that set, such as `.medium` on the package default's Inter (loaded in 400 and 600), draws the nearest loaded
  weight, the heavier on a tie, and prints one debug warning per family and weight. A Google font in the fallback list
  snaps the style's drawn weight — the primary's snapped weight, or the recipe's weight when the primary is an app or
  theme font — into its own set: the drawn weight when its set holds it, otherwise the nearest weight in it (the
  heavier on a tie), which can be lighter than the primary. The package asks google_fonts for
  no other weight, with run-time fetching on or off, so bundling exactly those weights keeps every normal-style Google
  font off the network; an italic face loads on first use, at the snapped weight. A font the theme ships as `files`
  or the app registers keeps the weight it is asked for.
- **Material text theme** — `StratumThemeApplication` inserts a Material `ThemeData` whose text theme resolves Stratum
  recipes for the active theme, locale, and window size: display and headline slots read `header`; title, body, and
  label slots read `body`. No slot sets a weight, so each draws its type's yaml weight: title and label slots draw the
  body weight (400 in the package default), not Material's medium.
- **Custom text size** — `StratumTextStyle.body.size(15)` sets a custom size of 15 logical pixels, with the metrics
  of the nearest named size. The size must be a finite number above 0: a debug build asserts it, and a release build
  skips the assert and reads any other size as unset, so the text takes `s16` for its size and its metrics.
- **Theme models** — the parsed theme types (`StratumThemeConfig`, `StratumColorSets`, `StratumTypography`,
  `StratumTypeStyle`, `StratumAnimationConfig`, and the models inside them) are immutable values with `copyWith`;
  their maps refuse changes, so derive a variant with `config.copyWith(name: ...)` instead of editing a map. A
  `StratumCurve` gives its Flutter `Curve` as `.curve` through `package:stratum_ui/stratum_ui.dart`.
  `StratumAnimationConfig.transitions` holds the `animation.transition` names, and
  `StratumTheme.of(context).animation.transition[windowSize]` gives the theme's `ScreenTransitionType` for a window
  size.
- **Before `preload`** — call `WidgetsFlutterBinding.ensureInitialized()` first: `preload` reads the asset manifest
  through `rootBundle`, which needs the binding. In a `testWidgets` test, the background parse runs on a real
  isolate, which the test's fake-async zone never finishes; run `preload`, or pump a tree rooted in
  `StratumThemePreloader` or `StratumSplashScreen`, under `tester.runAsync`.
- **`StratumThemeController`** — the registered themes and the active one. Build it before the first themed frame
  with `await StratumThemeController.preload(initialThemeId: savedId, onThemeChanged: save)`; `googleFontsTimeout`
  (default 3 s, also the limit of every switch) and `bundle` are optional. It registers every
  `assets/themes/<id>/theme.yaml` the app declares in pubspec as `<id>` (`themeIds`: `default` first, then
  alphabetical), and an app `default` folder layers over the package default. An `initialThemeId` that names no
  theme starts on `default` and calls `onThemeChanged('default')`, so the app overwrites its saved id; a theme file
  with problems throws `StratumThemeFormatException`.
  A theme file, bundled or in a zip, holds no YAML anchor, alias, or tag (`&a`, `*a`, `!x`), no mapping key that is a
  collection or an explicit `?` key (`[a]: x`, `{a: 1}: x`, `? a`), nests at most 64 collections, holds at most 256
  keys in one mapping and 2,048 in all, stays within 1 MiB, and holds a byte-order mark (U+FEFF) only as its own
  first character, never later even on its own line; past that it fails as `yaml_syntax` at the offending character,
  so write each value out, refer to a token with a quoted `"{group.path}"` alias, split a larger mapping, write each
  key as a plain or quoted value, and move or remove a stray byte-order mark.
  `switchTo(id)` completes after the new theme is active, keeps the current theme on screen while it loads and when
  it fails, throws `StratumThemeNotFoundException` for an unknown id, and lets the latest of overlapping switches
  win. For the active id it does nothing, unless a newer install of that id is registered and not yet on screen:
  then it shows that install, with no `onThemeChanged`. The package stores nothing: save the id `onThemeChanged`
  reports.
- **`StratumThemeApplication.controlled`** — `StratumThemeApplication.controlled(controller:, themeMode:,
  highContrast:, componentDefaults:, componentPartDefaults:, child:)` publishes the controller's active theme and
  rebuilds dependents once per switch; below it, `StratumThemeController.of(context)` and `maybeOf(context)` find the
  controller, so a theme picker calls `StratumThemeController.of(context).switchTo('brand')`.
  `StratumThemeApplication(themes:)` stays for a fixed theme set.
- **`StratumThemePreloader`** — the widget form of `preload`: `StratumThemePreloader(initialThemeId:,
  onThemeChanged:, googleFontsTimeout:, loading:, error:, builder: (context, controller) => ...)` shows `loading`
  until the start theme is active, then `builder`, or `error` with what preload threw; it reads its asset bundle from
  `DefaultAssetBundle` and disposes its controller when it leaves the tree. Pick it or `await preload(...)` before
  `runApp`, not both.
- **`StratumSplashScreen`** — the splash an app shows while it starts: place it above `MaterialApp` as the root of
  `runApp`, instead of `StratumThemePreloader` or an awaited `preload`. It keeps the platform's launch screen, or on
  the web the page's own loader, until the start theme is active, then runs `postload` with the controller and hands
  the one required `builder` one `StratumSplashState` at a time; the package draws no splash look, so the builder
  draws every state, the failure and its retry button included, and returns the app itself, never a route, at
  `StratumSplashDone`:

  ```dart
  runApp(
    StratumSplashScreen<AppData>(
      initialThemeId: savedThemeId,
      onThemeChanged: saveThemeId,
      themeMode: ThemeMode.system, // the modes the app gives its theme application
      postload: (context, controller) => loadAppData(), // bound its own time limits
      minimumDuration: firstLaunch ? const Duration(seconds: 2) : Duration.zero,
      builder: (context, state) => switch (state) {
        StratumSplashLoadingTheme() || StratumSplashLoadingApp() => const BrandSplash(),
        StratumSplashFailed(:final error, :final retry) =>
          BrandFailure(error: error, onRetry: retry),
        StratumSplashDone(:final controller, :final data) => MaterialApp(
          builder: (context, child) => StratumThemeApplication.controlled(
            controller: controller,
            themeMode: ThemeMode.system,
            child: child!,
          ),
          home: HomePage(data: data),
        ),
      },
    ),
  );
  ```

  `postload`'s context sits above the splash's own theme scope: read the active theme through `controller`, never
  `StratumTheme.of(context)`. If your own `AssetBundle` cannot read the package's embedded default theme either, the
  failed frame has no theme above it at all, and the read failure reaches `FlutterError.reportError` on its own; fix
  the bundle, since the package has nothing left to fall back to.

  Every frame before done has no `Overlay` and no `Localizations` above it — no `Tooltip`, no `TextField` — until
  the app's own `MaterialApp`. The splash wraps those frames in its own `Shortcuts`/`Actions` of
  `WidgetsApp.defaultShortcuts`/`defaultActions`, so Tab still reaches a focusable retry button and Enter or Space
  still activates it.

  `StratumSplashFailed.phase` says which step failed, `StratumSplashPhase.theme` (its `error` is the theme file's
  `StratumThemeFormatException`) or `StratumSplashPhase.postload` (what `postload` threw); `retry` runs that step
  again and the builder gets its loading state, while `minimumDuration` keeps counting from the first frame.
  `StratumSplashFailed.stackTrace` is `error`'s stack trace, `StackTrace.empty` when none was caught with it, for
  your own crash reporting. After a theme failure the builder's frames read the package default theme alone. Screen
  readers hear the built-in "Loading" label (Thai on a Thai device), or your `loadingLabel`, on every loading frame
  your builder draws. The app takes over in place by `exitTransition`, default `ScreenTransitionType.fadeThrough`,
  on the theme's `slow` level and `standard` curve unless you pass `exitDuration` and `exitCurve`; every type but
  `platform` and `cupertino` works, and reduced motion keeps only the fade a type has, as page routes do. Above
  `MaterialApp` the platform locale picks the text
  direction. On the web, remove your page's loader when `window` dispatches `stratum-splash-shown`:
  `window.addEventListener('stratum-splash-shown', () => document.getElementById('loader')?.remove());`. Keep
  first-launch timing in your own storage: the package stores nothing.
- **Remote theme zips** — hand a downloaded `<id>.zip` with the checksum your own API serves (never a file beside the
  zip): `StratumRemoteTheme(id:, bytes:, checksum: 'sha256:<64 hex>')`, caps `maxBytes` 20 MB and `maxEntries` 200 by
  default. Pass kept zips to `preload(remoteThemes: [...], onRemoteThemeError: (id, error) => ...)` or the same two
  parameters of `StratumThemePreloader`; a zip that fails is skipped and reported, so delete it and download it again.
  At run time `await controller.install(theme)`, then `switchTo(theme.id)`; installing the active id repaints in one
  step with no `onThemeChanged`. The latest install of an id that reaches registration wins, a bundled id too, for the
  run only; of overlapping `install` calls for one id, the later-started call that installs wins, and an earlier call
  that finishes after it completes normally while installing nothing, so await the call you started last; a later call
  that fails leaves an earlier one free to install. `default` is always refused. Ask your server for the zip of
  `StratumSchemaVersion.current`. `theme.yaml` sits at the zip root or in its one top folder; every `files:` font and
  asset slot it names must be in the zip; `Google/<Name>` fonts load as for a bundled theme. A failure throws
  `StratumRemoteThemeException` with a `code` (`StratumRemoteThemeErrorCode`), `themeFormat` carrying the FO-01 report
  in `formatException`. Its `path` field is entry text straight from the zip: escape it before your app logs or shows
  it, since a hostile zip crafts it. `StratumThemeFormatException` and each `StratumThemeFormatError` print their
  yaml paths and messages escaped, but an error's `path` field is the raw yaml path: escape it the same way.
- **Pack and check a theme zip** — from your app project, `dart run stratum_ui:stratum_theme pack <folder>` writes
  `<id>.zip` (the id is the folder name, or `--id`; `--out <folder>` to write elsewhere) and prints `sha256:<hex>`, the
  checksum your API serves; the same folder always packs to the same bytes, and a pack into the folder itself leaves its
  own last `<id>.zip` out. `dart run stratum_ui:stratum_theme check <file.zip>` runs your app's own install checks on a
  zip, over the package default and your `assets/themes/default/theme.yaml` when your `pubspec.yaml` lists it under
  `flutter: assets:`, as the file or as `assets/themes/default/` (`assets/themes/` does not cover it), the way your app
  reads it; a file you hold but do not list is not read and prints a `warning:`. `--app-default <path>` names another
  file; pass `--max-bytes` and `--max-entries` when your app raises a cap. A run that passes prints only the checksum on
  stdout; stderr names the defaults read, each problem with the code your app would report, and `warning:` lines that
  never fail it: files the theme does not name; entries the install never reads, such as anything under `__MACOSX/`, a
  `.DS_Store`, or a loose file beside the theme folder; and names that differ only in letter case, one line per two
  neighbors in name order. Exit 0 pass; 1 check failed, or a `pack` that stops before the check with one problem and no
  defaults line (`invalid_id`, a symbolic link or other special entry as `unsafe_entry_path`, or a file name or size a
  zip cannot hold as `unsafe_entry_path` or `archive_too_large`); 64 usage; 66 an input that cannot be read (the folder;
  a zip or `--app-default` that is not a regular file or cannot be read; your default theme; a file under the folder;
  the stratum_ui package or its default theme; a `pubspec.yaml` that is not a regular file, is longer than 1 MiB, cannot
  be read, or is not yaml, such as one holding an anchor, alias, or tag or nesting deeper than 64), an `--out` that is
  not a folder, or a zip that fails to write. Names starting with `.` and `__MACOSX/` stay out of a pack. An install
  refuses an entry name holding any character outside printable ASCII, U+0020 to U+007E (a control character, an
  accented letter, or a Thai letter alike), or a name Windows would not create unchanged (a part ending in a dot or a
  space, a part of dots only, any of `:`, `<`, `>`, `"`, `|`, `?`, `*`, a device name such as `CON`, `aux.txt`, or
  `CONIN$` in any letter case with trailing spaces before the dot trimmed, or a part holding `~` before a digit, an
  8.3 short-name marker such as `THEME~1.YAM`), and a folder entry that holds bytes; `pack` refuses such a file or
  folder name under the folder before it writes anything, so rename it. stratum_ui allows only the google_fonts
  version its CLI family list came from, so the CLI and your app accept the same `Google/<Name>` families. When
  `pub get` reports a google_fonts conflict, let your own google_fonts constraint allow the version stratum_ui's
  `pubspec.yaml` names.
- **Supported zip tools** — make a theme zip with `pack` or with 7-Zip, the two zip tools measured against the install;
  a zip Windows Explorer makes is not measured, so run `check` on it before you upload it.
- **Disabled opacity and scrim** — `opacity.disabled` in `theme.yaml`, a number from 0 to 1, is the opacity every
  disabled component paints at, and `opacity.scrim` is a modal layout's background scrim opacity; the package
  default sets 0.5 for both, and an app theme may leave the group out. Read them as
  `StratumThemeApplication.of(context).opacity.disabled` and `.opacity.scrim`. A value outside 0 to 1 throws
  `StratumThemeFormatException` with `expected_opacity` at its path, and a third key under `opacity` is
  `unknown_key`. The package default reads `$schema: stratum-theme/v1.5.0`; this package reads every `v1.0` to
  `v1.5` theme, while a package build that reads only up to `v1.2` refuses a `v1.3` theme as
  `unsupported_schema`, so a theme that must load on every build writes `v1.0.0` and leaves `opacity` out; one that
  must load on every build from `v1.1` on writes `v1.1.0` and keeps `disabled` but leaves `scrim` out.
- **Border, shadow, and blur tokens** — `border`, `shadow`, and `blur` in `theme.yaml` (format
  `stratum-theme/v1.2.0`) set every border width, drop shadow, and background blur, and the package default carries
  the Figma values. Read them in `build`: `StratumTheme.of(context).border.md` (a `double`; `sm` 0.5, `md` 1, `lg`
  1.5, and `md` is the usual width), `.shadow.level1` to `.level6` (each a `List<BoxShadow>` for
  `WidgetStyle.dropShadow`, colored from the active color set, so dark and high-contrast themes get their own), and
  `.blur.level1` to `.level6` (each an `ImageBlurFilter` for `WidgetStyle.backgroundBlur`, sigma half the Figma
  radius): `WidgetStyle(border: Border.all(width: theme.border.md, color: theme.color.border.defaults.normal),
  dropShadow: theme.shadow.level2, backgroundBlur: theme.blur.level3)`. A theme sets `border: {md: 2}`,
  `blur: {"3": 24}`, or a `shadow."2"` list of layers such as
  `{x: 0, y: 4, blur: 8, spread: 0, color: "{color.shadow.secondary}"}`, where `blur` is the Figma blur radius and
  `color` is a quoted hex, a `{palette...}` or `{transparent...}` alias, or `"{color.<group>.<name>}"`, a token of
  each color set; a list of at most 8 layers replaces the default's whole, and `[]` is no shadow. Every length a
  theme sets, in `space`, `radius`, `layouts` (the `N` of a `"N%"` too), `border`, `blur`, a layer's `x`, `y`, `blur`,
  and `spread`, and `typography` (`adjustSize`, each `scaleByWindowSize` entry, `spaceHeight`, and `letterSpacing`,
  the `N` of a `"N%"` too, negatives included), is a finite number from -10000 to 10000, and from 0 for `border`,
  `blur`, and a layer's `blur`. A bad value throws `StratumThemeFormatException` with `expected_dimension`,
  `expected_shadow`, or `expected_color` at its path, and a key the default lacks, such as `shadow.7`, is
  `unknown_key`. A `typography` that draws some text at a font size or a line box of 0 px or less is
  `expected_dimension` too: at text scale 1 the package tries every size `s10` to `s56`, with no window size and at
  each one, in every font a tag gives the type, and blames the `adjustSize`, the `scaleByWindowSize` entry, or the
  `spaceHeight` that does it, once per path, in the app and in the `stratum_theme` CLI alike. A package build
  that reads only up to `v1.1` refuses a
  `v1.2` theme as `unsupported_schema`, so a theme that must load there writes `v1.1.0` and leaves the three groups
  out. `AppBorder`, `AppShadow`, `AppFilter`, `StratumThemeData.filter`, and `screenBorderRadius` no longer exist;
  read the screen's corner radius from `context.deviceWindow.radius` (see Screen corner radius).
- **System bar look** — `system` in `theme.yaml` (format `stratum-theme/v1.4.0`) sets how the status bar and the
  navigation bar look, in `light` and `dark` and the optional partial overlays `highContrastLight` and
  `highContrastDark`, as `color` does: `statusBarIcons` and `navigationBarIcons` (`auto`, `light`, or `dark`; `auto`
  picks the icon color of higher contrast against what the page paints under the bar), `statusBarColor`,
  `navigationBarColor`, `navigationBarDividerColor`, and `appSwitcherColor` (a quoted hex or a color alias such as
  `"{color.light.background.default.normal}"`), and `statusBarContrast` and `navigationBarContrast` (`true` or
  `false`, Android's own contrast scrim). The package default sets `auto` icons, transparent bars, `false` and
  `true`, and the page background. The bar mode, the rotation lock, and the app switcher label are set in Dart only
  (see System bars): a `system` set holding `barMode`, `orientations`, or `appSwitcherLabel` throws
  `StratumThemeFormatException` with `unknown_key`, a bad icons value `expected_bar_icons`, and a bad flag
  `expected_boolean`. A package build that reads only up to `v1.3` refuses a `v1.4` theme as `unsupported_schema`.
- **Focus ring look** — `focus` in `theme.yaml` (format `stratum-theme/v1.5.0`) sets the focus ring's theme look:
  `light`, `dark`, and the optional partial overlays `highContrastLight` and `highContrastDark`, each with `outside`
  (`color`, `width`, `gap`) and `inside` (`color`, and a `width` of `hovered` and `focused`). Each color is a quoted
  hex color or an alias to a color token; a color whose alpha is 0 is `expected_color`, and a width of 0 is
  `expected_dimension`, since either hides the ring; a gap of 0 loads. A file that leaves the group out keeps the
  Figma `FocusBorder` look. A package build that reads only up to `v1.4` refuses a `v1.5` theme as
  `unsupported_schema`. Read it in code as `StratumTheme.of(context).focus`, a `StratumFocusTokens` of the six
  values for the active light, dark, or high-contrast data.
- Read the theme data, its default widget size, and the window size where a widget sits:
  `context.themeData()` (or `context.themeData(ThemeMode.dark)`), `context.defaultWidgetSize()`, and
  `context.windowSize`. Each throws a `FlutterError`: `themeData` and `defaultWidgetSize` name the missing
  `StratumThemeApplication`; the window-size error says how to wrap the app.
- **App-wide component defaults** — `StratumThemeApplication(componentDefaults: (theme) => {MyWidget:
  WidgetStyle(...)}, ...)` restyles every instance of a component type from one place; read it in a component's
  `build` through `StratumWidgetProps.resolveStyle(context, defaults, customStyle)`, never directly; the component
  base declares no `customStyle`, so a component of your own that takes one declares its own field, of its own type,
  and passes it as the third argument. A component drawn in several parts, such as a page layout, a modal layout, or
  a notice, instead takes `componentPartDefaults: (theme) => {ModalLayout: ModalLayoutStyle(...)}`, one parts style
  per component type; read it through
  `StratumComponentDefaults.partsOf<ModalLayoutStyle>(context, ModalLayout)`, null when none is registered, and a
  thrown `FlutterError` naming both types when the registered value is not a `ModalLayoutStyle`. Both builders run
  again whenever the active theme changes, and `StratumThemeApplication.wrap` copies both to a nested application.
  Under `StratumApplication`, pass both to it instead (see App assembly).
