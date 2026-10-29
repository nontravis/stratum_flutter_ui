# App Setup

## Install

- Stratum's notices wrap `toastification`, which pins `equatable ^2.0.5`, while Stratum's own `flutter_falconx`
  needs `equatable ^3.0.0`. pub reads overrides only in the app, so add these two lines to the app's `pubspec.yaml`
  when you add stratum_ui, and run `flutter pub get`:

  ```yaml
  dependency_overrides:
    equatable: ^3.0.0
  ```

  Remove them once stratum_ui's own `pubspec.yaml` no longer carries the override.

- Before adding the override, check what else in the app graph reads `equatable`: run `flutter pub deps --style=list` and
  look for other `equatable` dependents. The override silences every package's `equatable` constraint, and `equatable`
  3.0.0 is breaking (removed `EquatableMixin`, changed `toString`, dropped the `runtimeType` comparison of props), so a
  dependency still on `^2.x` runs on 3.0.0 untested. Run the app's tests after adding it.

## App assembly

- Wrap the app once:

  ```dart
  StratumApplication(
    initialThemeId: savedId,
    onThemeChanged: save,
    themeMode: savedMode,
    webZoom: (child) => StratumWebZoom(child: child),
    appBuilder: (context, stratum) => MaterialApp.router(
      theme: stratum.theme,
      darkTheme: stratum.darkTheme,
      themeMode: stratum.themeMode,
      builder: stratum.builder,
      routerConfig: router,
    ),
  )
  ```

  `stratum.builder` inserts the theme application, the update gate, the notice host (`notices: false` leaves it
  out), and web zoom, outer to inner; your router, locales, and providers stay yours. With a builder of your own,
  chain it: `builder: (context, child) => stratum.builder(context, MyWrapper(child: child!))`. `CupertinoApp` and
  `WidgetsApp` take the same `builder`. Add the `## Install` override lines first.
- `appBuilder` runs again on a theme switch, a `StratumApplication` rebuild, and a change of window size class, text
  scale, or platform locale: build the router and providers outside it.
- `themeMode:`, `highContrast:`, and `componentDefaults:` go on `StratumApplication`, which forwards them to the theme
  application; pass `stratum.themeMode` to the app widget. Never set the mode on `MaterialApp(themeMode:)` alone: the
  theme application inside its builder keeps the wrapper's `themeMode` (default `ThemeMode.system`) on every route.
- `controller:` hands in a `StratumThemeController` you hold, which the wrapper never disposes. With one, the preload
  inputs (`initialThemeId`, `onThemeChanged`, `googleFontsTimeout`, `remoteThemes`, `onRemoteThemeError`, `error`,
  `loadingBuilder`) are ignored; with none, the wrapper reads the first five once, at its first build. One
  exception: a rebuild that flips `controller:` from null to one while the widget settings load the null branch
  started is still pending shows `loadingBuilder`, else the background, until that load ends.
- `widgetSettings:` hands in a `StratumWidgetSettingsController` you hold, read once at the first build; with none,
  the wrapper reads the scope above, else makes its own over the default store and places a scope around the app
  for `setting:` on a `PageLayout` or `SplitLayout` below to read (see Widget settings). With `controller:` set, a
  settings controller this app uses must already be loaded.
- `loadingBuilder:` replaces the theme's background color shown until the start theme is active. `error:` is the
  frame for a start theme that fails to load, and the failure reaches only it, so log it there; with none, the failure
  goes to `FlutterError.reportError` and the background stays. Both build above the app widget, with no
  `Directionality` or theme: give a `Text` its `textDirection`.
- `onRemoteThemeError:` gets each kept zip that fails to install, so you delete it and download it again; with none,
  the failure goes to `FlutterError.reportError` instead.
- `updateGate:` wraps the inner layers in your own update gate; see Update gate.
- `noticeHost:` replaces the plain notice host `notices: true` builds; see Notices. Mount one `StratumApplication`
  with `notices: true` per process: the notice host is process-wide, so every other view's wrapper passes
  `notices: false`.
- `systemStyle:` forwards the app-wide system bar style to the theme application; see System bars.
- `componentPartDefaults:` forwards the app-wide parts style per component type to the theme application; see
  Themes, App-wide component defaults.

## Widget settings

- **Opt in per instance** — pass `setting: WidgetSettingKey.global()` to a `PageLayout` or `SplitLayout` to have
  Stratum remember that type's own sizes across every instance, or `setting: WidgetSettingKey.id('mail')` for the
  instances that share that id; with no `setting:` Stratum persists nothing. A stored value wins over a passed
  controller's, each value judged on its own; the controller's own value is the default only where the store holds
  none. The restore at the first build notifies no listener of a passed controller: read it after the first frame,
  not during it.
- **Load before the first frame** — `StratumSplashScreen` and `StratumApplication` load the settings beside the
  start theme, under the same held first frame, so a mounted `setting:` reads the loaded cache at its own first
  build. Pass `widgetSettings:` a `StratumWidgetSettingsController` of your own to call `switchUser` from
  `postload`, or preload it yourself ahead of either wrapper:

  ```dart
  // Without a Stratum wrapper: preload the device box before runApp.
  final settings = await StratumWidgetSettingsController.preload();
  runApp(StratumWidgetSettings(controller: settings, child: const MyApp()));

  // After sign-in, and at sign-out.
  await settings.switchUser('user-42');
  await settings.switchUser(null);
  ```

- **A box per widget type** — a plain app widget reads and writes its own settings through
  `StratumWidgetSettings.of(context, namespace: 'acme.inbox_filter')`, a declared, package-prefixed namespace that
  returns a `StratumWidgetSettingBox`: `box.global` is the part every instance of that widget type shares, and
  `box.id('mail')` the part shared only by instances carrying that id; `global` and an `id` never mix values, and
  neither leaks into another widget type's box. Each part has `getBool`/`setBool`, `getInt`/`setInt`,
  `getDouble`/`setDouble`, `getString`/`setString`, and `getStringList`/`setStringList`, plus `remove`; a write
  rebuilds only the readers of that value.

  ```dart
  final box = StratumWidgetSettings.of(context, namespace: 'acme.inbox_filter');
  final unreadOnly = box.global.getBool('unread_only') ?? false;
  ```

- **Per signed-in user** — `controller.switchUser('user-42')` loads that user's values, then swaps every reader at
  once, so no default frame shows under the new user; `switchUser(null)` returns to the device box at sign-out.
  `controller.clearUser('user-42')` clears only that user's Stratum keys, such as at account deletion.
- **Reset** — `controller.resetId(namespace, id)`, `controller.resetType(namespace)`, and `controller.resetAll()`
  reset by id, by type, or every Stratum setting of the current user; reset never touches the host app's own
  keys or another user's.
- **Swap the store** — the default store is `StratumSharedPreferencesSettingStore`, over `shared_preferences`.
  `StratumMemorySettingStore` is the in-memory one for tests; pass it to your own
  `StratumWidgetSettingsController(store: StratumMemorySettingStore())`.
- **Theme persistence stays the app's** — widget settings are their own store, separate from the theme id the app
  saves through `onThemeChanged`; this feature adds no persistence to the theme runtime.
- **Widget tests** — install `SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty()` in
  `setUp` (for example in `flutter_test_config.dart`) so every wrapper's own default store loads an empty box, or
  pass `widgetSettings:` a controller preloaded over `StratumMemorySettingStore`; with neither, a `StateError` about
  the missing platform instance reports once through `FlutterError.reportError`, which fails a `testWidgets` test
  that pumps `StratumSplashScreen` or `StratumApplication` with no theme controller, so add one of the two setups
  before pumping either.

## System bars

- **The theme's look** — `StratumTheme.of(context).systemStyle` is the theme's `SystemStyle` for the active mode: the
  look of the status bar and the navigation bar from the theme file's `system` set (see System bar look), with no bar
  mode, rotation lock, or app switcher label. `AppSystemUI` and `systemOverlayStyle` no longer exist, and the Material
  theme sets no app bar overlay style.
- **App-wide** — `StratumThemeApplication(systemStyle: SystemStyle(...))`, on both constructors, sets the app-wide
  layer over the theme's look: any look field, plus `barMode` (`SystemBarMode.edgeToEdge`, `immersive`,
  `immersiveSticky`, `leanBack`, `topOnly`, or `bottomOnly`), `orientations` (such as
  `[DeviceOrientation.portraitUp]`), and `appSwitcherLabel`, passed in the user's language. A null field takes the
  layer below. The application leaves the platform's own bar mode and rotation lock untouched until some layer sets
  `barMode` or `orientations`; once one has, an unset field falls back to `edgeToEdge` and no lock. An app that locks
  rotation in `AndroidManifest.xml` or hides the status bar in `Info.plist` keeps that native setting on its own, but
  once any page sets `orientations` or `barMode`, declare the app-wide lock or mode here instead, since Flutter
  cannot read the native value back. The application applies the merged style after each frame and is the
  one writer of the system chrome: never call `SystemChrome.setSystemUIOverlayStyle`, `setEnabledSystemUIMode`, or
  `setPreferredOrientations` yourself, and never set `AppBar.systemOverlayStyle` to force the icons; set
  `statusBarIcons` instead. The application paints `statusBarColor`, and on Android `navigationBarColor` with its
  `navigationBarDividerColor` line, under the bars itself, above every page, and sends the platform transparent bar
  colors, so a bar color shows on every Android version and on iOS; leave a bar color transparent for an edge-to-edge
  page. `auto` icons pick light or dark against what paints under each bar, the bar color the topmost, else the
  theme's page background; with no label set, the app widget's `title` shows, except a web router app with no
  `title:` of its own, which builds no `Title` widget to read — pass `title:` or an app-wide `appSwitcherLabel`.
  On the web only the label and
  `appSwitcherColor`, the browser theme color, apply; the bar mode and the rotation lock apply on Android and iOS
  only, and a platform that ignores a setting shows no error.
- **Per page** — wrap any screen, or a part of it, in `SystemStyleScope(style: SystemStyle(...), child: ...)`, with
  or without a page layout and on any router: its look fields apply at a bar its child covers, and its `barMode`,
  `orientations`, and `appSwitcherLabel` apply while its child paints. A dialog or sheet over the page keeps them, a
  pushed page with no scope returns to the app-wide style, and pop restores the page's own, with no
  `NavigatorObserver` and no restore code; only the shown tab of an `IndexedStack` counts. An inner scope wins field
  by field over an outer one. Pass the label in the user's language (FO-09).
- **Fill under a bar** — wrap every surface that paints under the status bar or the navigation bar, such as a
  header, a full-screen video, or a translucent scrim, in `SystemBarFill(color: <the color it paints>, child: ...)`,
  so `auto` icons pick the color of higher contrast against it. A translucent color blends over the fills beneath it.
  Neither `SystemStyleScope` nor `SystemBarFill` paints, adds a semantics node, takes focus, or handles a gesture; a
  bar color a scope sets, the application paints under the bar.
