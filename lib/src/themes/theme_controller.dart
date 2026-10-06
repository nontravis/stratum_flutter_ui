import 'package:stratum_ui/src/src.dart';
import 'package:stratum_ui/src/themes/remote/remote_theme.dart';
import 'package:stratum_ui/src/themes/remote/remote_theme_bundle.dart';
import 'package:stratum_ui/src/themes/remote/remote_theme_installer.dart';
import 'package:stratum_ui/src/themes/theme_font_loader.dart';
import 'package:stratum_ui/src/themes/theme_parse.dart';
import 'package:stratum_ui/src/themes/typography/google_font_weights.dart';
import 'package:stratum_ui/src/themes/typography/google_fonts_lookup.dart';

/// A registered theme's parse source id and its folder in the bundle.
typedef _Registered = ({String sourceId, String folder});

/// Thrown by `StratumThemeController.switchTo` for an id that names no
/// registered theme: the error `theme_not_found` of
/// `docs/specs/stratum_ui/themes/s05_errors.md`.
@immutable
class StratumThemeNotFoundException implements Exception {
  const new(this.id, this.registeredIds);

  /// The id the switch asked for.
  final String id;

  /// Every registered theme id, `default` first.
  final List<String> registeredIds;

  @override
  String toString() =>
      'StratumThemeNotFoundException: no theme "$id"; registered: '
      '${registeredIds.join(', ')}';
}

/// The app's registered themes and the active one (FO-03 theme registry).
///
/// [preload] builds it before the first themed frame; hand it to
/// `StratumThemeApplication.controlled`. It holds the choice in memory
/// only: the app saves the id `onThemeChanged` reports and passes it back
/// as `initialThemeId` at the next start.
class StratumThemeController extends ChangeNotifier {
  new _(
    this._bundle,
    this._registry,
    this._packageDefault,
    this._appDefault,
    this._googleFontsTimeout,
    this._onThemeChanged,
  ) {
    if (kFlutterMemoryAllocationsEnabled) {
      ChangeNotifier.maybeDispatchObjectCreation(this);
    }
  }

  /// The parse id of the package default theme file; the app's own
  /// `default` file keeps the id `default`.
  static const _packageDefaultId = 'stratum-default';
  static const _packageDefaultFolder =
      'packages/stratum_ui/assets/themes/default';
  static final _themeFile = RegExp(r'^assets/themes/([^/]+)/theme\.yaml$');

  final RemoteThemeBundle _bundle;
  final StratumThemeSource _packageDefault;
  final StratumThemeSource? _appDefault;
  final Duration _googleFontsTimeout;
  final ValueChanged<String>? _onThemeChanged;

  /// Each registered id with its parse source id and folder: a bundled
  /// theme reads `assets/themes/<id>`, a theme installed from a zip
  /// `stratum-remote/<id>/<generation>` in [_bundle] (FO-04 design D3).
  final Map<String, _Registered> _registry;

  /// Every registered theme id: `default` first, then every other id,
  /// bundled or installed from a zip, in alphabetical order (FO-03 US-01
  /// FR-02; FO-04 US-01 FR-03).
  List<String> get themeIds => _themeIds;

  // Assigned again when an install registers an id, so not final.
  late List<String> _themeIds = _sortedIds();

  /// The folder of the theme on screen.
  String _activeFolder = '';

  /// How many loads and swaps in flight read each remote folder.
  final _pins = <String, int>{};

  /// The sequence number of the latest `install` call each id started.
  final _installStarted = <String, int>{};

  /// The sequence number of the latest `install` call each id registered;
  /// a call registers only above it, so an earlier call that finishes
  /// after a later one registered registers nothing, and a later call that
  /// fails never blocks an earlier one (main ruling 2026-10-05, N4).
  final _installRegistered = <String, int>{};

  /// The id the latest `switchTo` call named.
  String? _switchTarget;

  /// The generation of the switch whose load is in flight, else null.
  int? _switchInFlight;

  /// The overlay bundle that serves installed zips; `StratumThemeAssetView`
  /// reads a remote slot through it.
  @internal
  RemoteThemeBundle get remoteBundle => _bundle;

  List<String> _sortedIds() => List.unmodifiable([
    'default',
    ...(_registry.keys.where((id) => id != 'default').toList()..sort()),
  ]);

  late String _activeId;
  late StratumThemeSet _themes;

  /// Counts switches, so a switch that a later one overtook drops its
  /// result (FO-03 US-02 FR-01 E05).
  int _generation = 0;

  bool _disposed = false;

  /// The id of the active theme.
  String get activeId => _activeId;

  /// The four theme data of the active theme.
  StratumThemeSet get themes => _themes;

  /// The controller of the nearest `StratumThemeApplication.controlled`
  /// above [context], or null when there is none; [context] rebuilds on
  /// every switch.
  ///
  /// Walks past a plain `StratumThemeApplication(themes:)` nested below a
  /// controlled one, so it never hides the controller above it.
  static StratumThemeController? maybeOf(BuildContext context) {
    final nearest = context
        .dependOnInheritedWidgetOfExactType<StratumThemeApplication>();
    if (nearest == null) return null;
    if (nearest.controller != null) return nearest.controller;
    var element = context
        .getElementForInheritedWidgetOfExactType<StratumThemeApplication>();
    while (element != null) {
      InheritedElement? next;
      element.visitAncestorElements((ancestor) {
        next = ancestor
            .getElementForInheritedWidgetOfExactType<StratumThemeApplication>();
        return false;
      });
      if (next == null) return null;
      final controller = (next!.widget as StratumThemeApplication).controller;
      if (controller != null) {
        context.dependOnInheritedElement(next!);
        return controller;
      }
      element = next;
    }
    return null;
  }

  /// The controller of the nearest `StratumThemeApplication.controlled`
  /// above [context]; throws a [FlutterError] when there is none.
  static StratumThemeController of(BuildContext context) {
    final controller = maybeOf(context);
    if (controller == null) {
      throw FlutterError(
        'StratumThemeController.of() called with a context that has no '
        'StratumThemeApplication.controlled above it.',
      );
    }
    return controller;
  }

  /// Switches to the theme [id]: reads it merged over the package default
  /// and the app's `default`, loads its fonts while the current theme stays
  /// on screen, then makes it active in one step and calls
  /// `onThemeChanged` with [id] (FO-03 US-02 FR-01, US-03 FR-02).
  ///
  /// Completes after the new theme is active. Throws
  /// [StratumThemeNotFoundException] for an id that names no registered
  /// theme, and `StratumThemeFormatException` for a theme file that fails
  /// to parse; either leaves the active theme as it was. A switch to the
  /// active id changes nothing. When switches overlap the latest wins: an
  /// overtaken switch completes with no error and no callback, and its
  /// theme is dropped. Only the active theme stays parsed, so a switch back
  /// reads its file again; its font files stay registered.
  Future<void> switchTo(String id) async {
    if (!themeIds.contains(id)) {
      throw StratumThemeNotFoundException(id, themeIds);
    }
    final generation = ++_generation;
    _switchTarget = id;
    if (id == _activeId) return;
    final entry = _registry[id]!;
    _pin(entry.folder);
    _switchInFlight = generation;
    try {
      final themes = await _load(entry, generation);
      if (themes == null || _disposed) return;
      final previous = _activeFolder;
      _themes = themes;
      _activeId = id;
      _activeFolder = entry.folder;
      notifyListeners();
      _onThemeChanged?.call(id);
      _release(previous);
    } finally {
      if (_switchInFlight == generation) _switchInFlight = null;
      _unpin(entry.folder);
    }
  }

  /// Installs a theme zip the app downloaded (FO-04 US-01 FR-01 to FR-03):
  /// checks the id, the checksum, and the zip, reads the theme over the
  /// package default and the app's `default`, and registers it under its
  /// id, replacing an earlier install of that id or a bundled theme of that
  /// id for the app's run. Then call [switchTo] to show it.
  ///
  /// An install of a non-active id registers with no repaint and no
  /// callback. An install of the active id loads the new theme's fonts and
  /// swaps it in one step, with no `onThemeChanged`, since the id does not
  /// change; a switch to another id that starts before that swap wins, and
  /// the install keeps its registration, while a switch to the same id
  /// changes nothing and the swap goes ahead. An install of an id that the
  /// latest switch is still loading acts as a later switch to that id: the
  /// earlier switch is dropped, and the screen lands on the newest install
  /// in one step with one `onThemeChanged`. Of overlapping install calls
  /// for one id, the later-started call that registers wins: an earlier
  /// call that finishes after it registers nothing and completes with no
  /// error, and a later call that fails leaves the earlier one free to
  /// register. Throws
  /// [StratumRemoteThemeException] for a zip it refuses, and leaves every
  /// registered theme and the active theme as they were.
  Future<void> install(StratumRemoteTheme theme) async {
    final call = _installStarted[theme.id] =
        (_installStarted[theme.id] ?? 0) + 1;
    final switches = _generation;
    final install = await RemoteThemeInstaller.prepare(
      theme,
      packageDefault: _packageDefault,
      appDefault: _appDefault,
    );
    if (_disposed || call <= (_installRegistered[install.id] ?? 0)) return;
    _installRegistered[install.id] = call;
    _registerRemote(install);
    if (install.id != _activeId) {
      if (_switchInFlight == _generation && _switchTarget == install.id) {
        await switchTo(install.id);
      }
      return;
    }
    _pin(install.folder);
    try {
      await Future.wait([
        _registerFontFiles(install.config.typography),
        _waitForGoogleFonts(install.config.typography),
      ]);
      if (_disposed ||
          _installRegistered[install.id] != call ||
          _activeId != install.id ||
          (switches != _generation && _switchTarget != install.id)) {
        return;
      }
      final previous = _activeFolder;
      _themes = StratumThemeSet.fromConfig(install.config);
      _activeFolder = install.folder;
      notifyListeners();
      _release(previous);
    } finally {
      _unpin(install.folder);
    }
  }

  /// D2 step 11: serves [install]'s entries and registers its id,
  /// replacing the earlier entry of that id, whose folder drops once
  /// nothing uses it.
  void _registerRemote(RemoteInstall install) {
    final previous = _registry[install.id];
    _bundle.add(install.folder, install.entries);
    _registry[install.id] = (
      sourceId: install.sourceId,
      folder: install.folder,
    );
    _themeIds = _sortedIds();
    if (previous != null) _release(previous.folder);
  }

  void _pin(String folder) => _pins[folder] = (_pins[folder] ?? 0) + 1;

  void _unpin(String folder) {
    final left = (_pins[folder] ?? 1) - 1;
    if (left == 0) {
      _pins.remove(folder);
    } else {
      _pins[folder] = left;
    }
    _release(folder);
  }

  /// Drops a remote [folder] from memory once no theme on screen, no
  /// registry entry, and no load in flight uses it (FO-04 design R10 OQ4).
  void _release(String folder) {
    if (!folder.startsWith('${RemoteThemeBundle.root}/')) return;
    if (folder == _activeFolder || _pins.containsKey(folder)) return;
    if (_registry.values.any((entry) => entry.folder == folder)) return;
    _bundle.remove(folder);
  }

  @override
  void dispose() {
    _disposed = true;
    _bundle.clear();
    super.dispose();
  }

  /// Discovers the app's bundled themes, reads the start theme merged over
  /// the package default and the app's own `default`, loads its fonts, and
  /// returns the controller with that theme active (FO-03 US-01 FR-02,
  /// FR-03; US-03 FR-01; US-05).
  ///
  /// The start theme is [initialThemeId], else `default`. An id that names
  /// no registered theme starts on `default`, logs a debug warning naming
  /// the id, and calls [onThemeChanged] with `default`, the only call
  /// preload makes. A theme file that fails to parse throws
  /// `StratumThemeFormatException`. Google fonts get [googleFontsTimeout]
  /// to load, here and at every switch. [bundle] defaults to [rootBundle].
  static Future<StratumThemeController> preload({
    String? initialThemeId,
    ValueChanged<String>? onThemeChanged,
    Duration googleFontsTimeout = const Duration(seconds: 3),
    AssetBundle? bundle,
  }) async {
    final assets = bundle ?? rootBundle;
    final manifest = await AssetManifest.loadFromAssetBundle(assets);
    final bundled = {
      for (final key in manifest.listAssets())
        if (_themeFile.firstMatch(key) case final match?) match[1]!,
    };
    final controller = StratumThemeController._(
      RemoteThemeBundle(assets),
      {
        'default': (sourceId: 'default', folder: 'assets/themes/default'),
        for (final id in bundled)
          id: (sourceId: id, folder: 'assets/themes/$id'),
      },
      StratumThemeSource(
        id: _packageDefaultId,
        folder: _packageDefaultFolder,
        yaml: await assets.loadString(
          '$_packageDefaultFolder/theme.yaml',
          cache: false,
        ),
      ),
      bundled.contains('default')
          ? StratumThemeSource(
              id: 'default',
              folder: 'assets/themes/default',
              yaml: await assets.loadString(
                'assets/themes/default/theme.yaml',
                cache: false,
              ),
            )
          : null,
      googleFontsTimeout,
      onThemeChanged,
    );
    final requested = initialThemeId ?? 'default';
    final fellBack = !controller.themeIds.contains(requested);
    if (fellBack) {
      _warn(
        'initialThemeId "$requested" names no registered theme; starting on '
        'default',
      );
    }
    final startId = fellBack ? 'default' : requested;
    StratumThemeSet? themes;
    try {
      themes = await controller._load(controller._registry[startId]!, 0);
    } on Object {
      controller.dispose();
      rethrow;
    }
    controller
      .._themes = themes!
      .._activeId = startId
      .._activeFolder = controller._registry[startId]!.folder;
    if (fellBack) controller._onThemeChanged?.call('default');
    return controller;
  }

  /// Reads the theme of [entry] merged over the package default and the
  /// app's `default`, registers its font files, waits for its Google
  /// fonts, and returns its theme set; null when a later switch overtook
  /// the switch numbered [generation].
  Future<StratumThemeSet?> _load(_Registered entry, int generation) async {
    final layers = [
      ?_appDefault,
      if (entry.sourceId != 'default')
        StratumThemeSource(
          id: entry.sourceId,
          folder: entry.folder,
          yaml: await _bundle.loadString(
            '${entry.folder}/theme.yaml',
            cache: false,
          ),
        ),
    ];
    if (generation != _generation) return null;
    StratumThemeConfig config;
    try {
      config = await ThemeParse.run(_packageDefault, layers);
    } on Object {
      if (generation != _generation || _disposed) return null;
      rethrow;
    }
    if (generation != _generation) return null;
    final themes = StratumThemeSet.fromConfig(config);
    await Future.wait([
      _registerFontFiles(config.typography),
      _waitForGoogleFonts(config.typography),
    ]);
    if (generation != _generation) return null;
    return themes;
  }

  /// Registers each file of every `theme` font once, under the font's
  /// family, which already names its source theme (FO-03 US-05 FR-01). A
  /// file another load is still registering is waited for, not loaded
  /// again.
  Future<void> _registerFontFiles(StratumTypography typography) {
    final registrations = ThemeFontLoader.registrations;
    final waits = <Future<void>>{};
    for (final font in typography.fonts.values) {
      if (font.source != StratumFontSource.theme) continue;
      final fresh = {
        for (final path in font.files)
          if (!registrations.containsKey('${font.family}\n$path')) path,
      };
      if (fresh.isNotEmpty) {
        final registering = _register(font.family, fresh.toList());
        for (final path in fresh) {
          registrations['${font.family}\n$path'] = registering;
        }
      }
      for (final path in font.files) {
        waits.add(registrations['${font.family}\n$path']!);
      }
    }
    return Future.wait(waits);
  }

  /// Reads [paths] and registers the files that read under [family]; a
  /// file the bundle lacks logs and leaves its text in the fallback fonts
  /// (FO-03 US-05 FR-01 E04). A registration that fails also logs, leaves
  /// the text in its fallback fonts, and drops [paths] from
  /// `ThemeFontLoader.registrations`, so the next theme that needs one of
  /// them registers it again (owner ruling R8).
  Future<void> _register(String family, List<String> paths) async {
    final files = <ByteData>[];
    for (final path in paths) {
      try {
        files.add(await _bundle.load(path));
      } on Object {
        final folder = path.substring(0, path.lastIndexOf('/') + 1);
        _warn(
          'font file "$path" is not in the asset bundle; add "- $folder" '
          'under flutter: assets: in pubspec.yaml',
        );
      }
    }
    if (files.isEmpty) return;
    try {
      await ThemeFontLoader.load(family, files);
    } on Object catch (error) {
      for (final path in paths) {
        unawaited(ThemeFontLoader.registrations.remove('$family\n$path'));
      }
      _warn(
        'the font files of "$family" failed to load ($error); its text uses '
        'the fallback fonts',
      );
    }
  }

  /// Starts every Google font of [typography] in each weight of its weight
  /// set (`GoogleFontWeights.of`, the rule the resolver draws by too), in
  /// normal style, then waits for them up to the time limit; a timeout or a
  /// failure goes on with the fallback fonts (FO-03 US-05 FR-02).
  Future<void> _waitForGoogleFonts(StratumTypography typography) async {
    final weights = GoogleFontWeights.of(typography);
    if (weights.isEmpty) return;
    for (final MapEntry(key: name, value: fontWeights) in weights.entries) {
      for (final weight in fontWeights) {
        GoogleFontsLookup.family(name, weight: weight, style: FontStyle.normal);
      }
    }
    try {
      await GoogleFontsLookup.pending().timeout(_googleFontsTimeout);
    } on Object {
      // Past the time limit, or a font failed: the theme shows with that
      // text in its fallback fonts (FO-03 US-05 FR-02 E02, E04).
    }
  }

  static void _warn(String message) {
    if (kDebugMode) debugPrint('Stratum theme: $message');
  }
}
