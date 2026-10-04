import 'package:stratum_ui/src/src.dart';
import 'package:stratum_ui/src/themes/theme_font_loader.dart';
import 'package:stratum_ui/src/themes/theme_parse.dart';
import 'package:stratum_ui/src/themes/typography/google_fonts_lookup.dart';

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
    this.themeIds,
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

  final AssetBundle _bundle;
  final StratumThemeSource _packageDefault;
  final StratumThemeSource? _appDefault;
  final Duration _googleFontsTimeout;
  final ValueChanged<String>? _onThemeChanged;

  /// Every registered theme id: `default` first, then each theme the app
  /// bundles, in alphabetical order (FO-03 US-01 FR-02).
  final List<String> themeIds;

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
    if (id == _activeId) return;
    final themes = await _load(id, generation);
    if (themes == null || _disposed) return;
    _themes = themes;
    _activeId = id;
    notifyListeners();
    _onThemeChanged?.call(id);
  }

  @override
  void dispose() {
    _disposed = true;
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
      assets,
      List.unmodifiable([
        'default',
        ...bundled.where((id) => id != 'default').toList()..sort(),
      ]),
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
      themes = await controller._load(startId, 0);
    } on Object {
      controller.dispose();
      rethrow;
    }
    controller
      .._themes = themes!
      .._activeId = startId;
    if (fellBack) controller._onThemeChanged?.call('default');
    return controller;
  }

  /// Reads [id] merged over the package default and the app's `default`,
  /// registers its font files, waits for its Google fonts, and returns its
  /// theme set; null when a later switch overtook the switch numbered
  /// [generation].
  Future<StratumThemeSet?> _load(String id, int generation) async {
    final layers = [
      ?_appDefault,
      if (id != 'default')
        StratumThemeSource(
          id: id,
          folder: 'assets/themes/$id',
          yaml: await _bundle.loadString(
            'assets/themes/$id/theme.yaml',
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

  /// Starts every Google font the yaml declares a weight for, in normal
  /// style, then waits for them up to the time limit; a timeout or a
  /// failure goes on with the fallback fonts (FO-03 US-05 FR-02).
  ///
  /// A font a tag names for a type, as `font` or `mono`, loads in that
  /// type's weight, `table` taking body's; a tag's theme-wide `mono` loads
  /// in every type's weight.
  Future<void> _waitForGoogleFonts(StratumTypography typography) async {
    FontWeight weightOf(FontType type) =>
        typography.types[type == FontType.table ? FontType.body : type]!.weight;
    final every = {for (final type in FontType.values) weightOf(type)};
    final weights = <String, Set<FontWeight>>{};
    void use(String? key, Iterable<FontWeight> typeWeights) {
      final font = key == null ? null : typography.fonts[key];
      if (font == null || font.source != StratumFontSource.google) return;
      (weights[font.family] ??= {}).addAll(typeWeights);
    }

    for (final set in typography.families.values) {
      for (final type in FontType.values) {
        if (set.types[type] case final ref?) {
          use(ref.font, [weightOf(type)]);
          use(ref.mono, [weightOf(type)]);
        }
        // The resolver draws every tag's body font as a fallback at the
        // requested type's weight (resolver.dart `_fallback`), even for a
        // type the tag never names.
        use(set.types[FontType.body]?.font, [weightOf(type)]);
      }
      use(set.mono, every);
    }
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
