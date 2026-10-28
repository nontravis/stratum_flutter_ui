import 'package:stratum_ui/src/src.dart';
import 'package:stratum_ui/src/themes/typography/google_font_weights.dart';
import 'package:stratum_ui/src/themes/typography/google_fonts_lookup.dart';
import 'package:stratum_ui/src/themes/typography/text_size.dart';

typedef _CacheKey = (StratumTextStyle, Locale, WindowSize?, TextScaler);

/// Turns a [StratumTextStyle] plus the screen environment into a
/// [TextStyle]. Reads no `BuildContext`.
///
/// Keeps one cache per [StratumThemeData] instance, so a theme swap drops
/// the old cache with the old theme.
abstract final class TypographyResolver {
  /// The most entries one theme's cache holds before it clears itself.
  static const maxCacheEntries = 512;

  static final _caches = Expando<Map<_CacheKey, TextStyle>>(
    'TypographyResolver cache',
  );
  static final _warned = <String>{};
  static final _warnedWeights = <(String, FontWeight)>{};

  /// The [TextStyle] for [recipe] under [theme], [locale], [windowSize],
  /// and [textScaler]; the same instance while the cache holds it.
  ///
  /// A null [windowSize] adds no window scale.
  static TextStyle resolve(
    StratumTextStyle recipe, {
    required StratumThemeData theme,
    required Locale locale,
    required WindowSize? windowSize,
    required TextScaler textScaler,
  }) {
    final cache = _caches[theme] ??= {};
    final key = (recipe, locale, windowSize, textScaler);
    if (cache[key] case final style?) return style;
    if (cache.length >= maxCacheEntries) cache.clear();
    return cache[key] = _resolve(recipe, theme, locale, windowSize, textScaler);
  }

  static TextStyle _resolve(
    StratumTextStyle recipe,
    StratumThemeData theme,
    Locale locale,
    WindowSize? windowSize,
    TextScaler textScaler,
  ) {
    final typography = theme.typography;
    final type = recipe.fontType;
    final metricsType = type == FontType.table ? FontType.body : type;
    final style = typography.types[metricsType];
    if (style == null) {
      throw StateError('No style for type "${metricsType.name}".');
    }
    final base = _customSize(recipe) ?? recipe.fontSize.value;
    final metrics = _metrics(style, recipe);
    final mono = recipe.isMono && type != FontType.code;
    final tags = _tags(locale, typography);
    final primaryKey = mono
        ? _monoKey(typography, type, tags)
        : _fontKey(typography, type, tags);
    final font = typography.fonts[primaryKey];
    if (font == null) {
      throw StateError('No font for key "$primaryKey".');
    }

    final sizes = textSizeOf(
      base: base,
      window: windowSize?.name,
      ownScale: windowSize == null ? null : _byName(style.scaleByWindowSize),
      themeScale: windowSize == null
          ? null
          : {
              for (final size in WindowSize.values)
                if (typography.scaleByWindowSize?.names(size) ?? false)
                  size.name: typography.scaleByWindowSize!.valueFor(size),
            },
      adjustSize: font.adjustSize,
      spaceHeight: metrics.spaceHeight,
      scale: textScaler.scale,
    );
    final weight = recipe.fontWeight ?? style.weight;
    final googleWeights = GoogleFontWeights.of(typography);
    final drawn = _snap(googleWeights, font, weight);
    final primaryFamily = _familyOf(font, drawn, recipe.fontStyle);
    final fallback = _fallback(
      typography,
      type,
      mono,
      primaryKey,
      primaryFamily,
      font.source == StratumFontSource.google ? drawn : weight,
      recipe.fontStyle,
      googleWeights,
    );

    return TextStyle(
      color: recipe.customColor ?? _color(theme.color, recipe.colorRole),
      fontSize: sizes.drawnFontSize,
      fontWeight: drawn,
      fontStyle: recipe.fontStyle,
      letterSpacing: metrics.letterSpacing.resolve(
        of: textScaler.scale(sizes.drawnSize),
      ),
      height: sizes.drawnLineBox / textScaler.scale(sizes.drawnFontSize),
      leadingDistribution: TextLeadingDistribution.even,
      fontFamily: primaryFamily,
      fontFamilyFallback: fallback.isEmpty ? null : fallback,
      fontFeatures: type == FontType.table
          ? const [FontFeature.tabularFigures()]
          : null,
      decoration: recipe.textDecoration,
      shadows: recipe.textShadows,
    );
  }

  /// [font]'s family at [weight] and [style]: its `qualifiedFamily` for an
  /// app font, and for a theme font, whose family already names its source
  /// theme (`<source theme id>/<family>`); `GoogleFontsLookup.family` for a
  /// Google font, since its family depends on the weight and style. A
  /// caller passes a Google font's snapped weight (see [_snap]).
  static String _familyOf(
    StratumFontData font,
    FontWeight weight,
    FontStyle? style,
  ) => font.source == StratumFontSource.google
      ? GoogleFontsLookup.family(font.family, weight: weight, style: style)
      : font.qualifiedFamily;

  /// The weight [font] draws [weight] in. A Google font draws only in its
  /// weight set (`GoogleFontWeights.of`, FO-02 typography s03 INV-13):
  /// a weight outside a non-empty set snaps to the nearest one, the heavier
  /// on a tie, with one debug warning per family and requested weight per
  /// run. An app or theme font keeps [weight]: the engine picks its face
  /// from its files.
  static FontWeight _snap(
    Map<String, Set<FontWeight>> googleWeights,
    StratumFontData font,
    FontWeight weight,
  ) {
    if (font.source != StratumFontSource.google) return weight;
    final snapped = GoogleFontWeights.snap(
      weight,
      googleWeights[font.family] ?? const <FontWeight>{},
    );
    if (snapped != weight &&
        kDebugMode &&
        _warnedWeights.add((font.family, weight))) {
      debugPrint(
        'Stratum theme: Google font "${font.family}" is not loaded in '
        'weight ${weight.value}; drawing ${snapped.value}',
      );
    }
    return snapped;
  }

  /// The metrics of the requested size, else of the nearest defined size.
  static StratumSizeMetrics _metrics(
    StratumTypeStyle style,
    StratumTextStyle recipe,
  ) {
    final custom = _customSize(recipe);
    if (custom != null) {
      return style.sizes[_nearest(style, custom, recipe.fontType)]!;
    }
    if (style.sizes[recipe.fontSize] case final metrics?) return metrics;
    final nearest = _nearest(style, recipe.fontSize.value, recipe.fontType);
    _warnOnce(
      '${recipe.fontType.name} has no size ${recipe.fontSize.name}; '
      'using ${nearest.name}',
    );
    return style.sizes[nearest]!;
  }

  /// [recipe]'s custom size when it is a finite number above 0, else null.
  /// The recipe asserts it in a debug build; a release build skips the
  /// assert, so an invalid one reads as unset here and the text takes the
  /// recipe's named size (FO-02 US-01 FR-01 E07).
  static double? _customSize(StratumTextStyle recipe) {
    final custom = recipe.customSize;
    return custom != null && isDrawableSize(custom) ? custom : null;
  }

  /// The defined size closest to [target], the smaller one on a tie
  /// (`nearestFontSize`, which the load-time draw-size check reads too).
  static FontSize _nearest(
    StratumTypeStyle style,
    double target,
    FontType type,
  ) =>
      nearestFontSize(style.sizes.keys, target) ??
      (throw StateError('No sizes for type "${type.name}".'));

  /// [scale]'s entries by window size name, as `textSizeOf` reads them.
  static Map<String, StratumDimension>? _byName(
    Map<WindowSize, StratumDimension>? scale,
  ) => scale == null
      ? null
      : {for (final MapEntry(:key, :value) in scale.entries) key.name: value};

  /// The family sets for [locale], most specific first: `<lang>_<country>`,
  /// `<lang>`, then `default`.
  static List<StratumFamilySet> _tags(
    Locale locale,
    StratumTypography typography,
  ) {
    final language = locale.languageCode;
    final country = locale.countryCode;
    return [
      if (country != null && country.isNotEmpty) '${language}_$country',
      language,
      'default',
    ].map((tag) => typography.families[tag]).nonNulls.toList();
  }

  /// The mono font of [type] in [family]: the type's own mono, else the
  /// tag's theme-wide mono, or null. No cross-type rule: a type looks only
  /// at its own entry.
  static String? _monoOf(StratumFamilySet family, FontType type) =>
      family.types[type]?.mono ?? family.mono;

  static String _fontKey(
    StratumTypography typography,
    FontType type,
    List<StratumFamilySet> tags,
  ) {
    for (final family in tags) {
      if (family.types[type] case final ref?) return ref.font;
    }
    throw StateError('No font for type "${type.name}".');
  }

  /// The type's mono along every tag, then each tag's theme-wide mono,
  /// then the non-mono font with a warning.
  static String _monoKey(
    StratumTypography typography,
    FontType type,
    List<StratumFamilySet> tags,
  ) {
    for (final family in tags) {
      if (family.types[type]?.mono case final mono?) return mono;
    }
    for (final family in tags) {
      if (family.mono case final mono?) return mono;
    }
    final key = _fontKey(typography, type, tags);
    _warnOnce(
      'no mono font for ${type.name}; '
      'using ${typography.fonts[key]!.family}',
    );
    return key;
  }

  /// The families of [type] in every tag, `default` first, then yaml
  /// order; the mono font before the font when [mono] is set; then every
  /// tag's `body` font. Without [primaryKey] itself, and without
  /// duplicates by family or [primaryFamily]. Each family resolves at
  /// [style], and a Google family at [weight] — the style's drawn weight,
  /// the primary's snapped weight, or the resolved weight when the primary
  /// is an `app` or `theme` font — snapped into its own weight set (see
  /// [_snap] and [_familyOf]): the drawn weight when the set holds it, else
  /// the nearest weight in the set, the heavier on a tie, which can be
  /// lighter than the primary.
  static List<String> _fallback(
    StratumTypography typography,
    FontType type,
    bool mono,
    String primaryKey,
    String primaryFamily,
    FontWeight weight,
    FontStyle? style,
    Map<String, Set<FontWeight>> googleWeights,
  ) {
    final families = [
      ?typography.families['default'],
      for (final MapEntry(:key, :value) in typography.families.entries)
        if (key != 'default') value,
    ];
    final keys = <String>{
      for (final family in families) ...[
        if (mono) ?_monoOf(family, type),
        ?family.types[type]?.font,
      ],
      for (final family in families) ?family.types[FontType.body]?.font,
    }..remove(primaryKey);
    final qualifieds = <String>{};
    for (final key in keys) {
      final font = typography.fonts[key]!;
      qualifieds.add(
        _familyOf(font, _snap(googleWeights, font, weight), style),
      );
    }
    return (qualifieds..remove(primaryFamily)).toList();
  }

  /// The color of [role] in [colors]: the seven `text.default` roles by
  /// name, and the three brand roles on `text.color.brand` (spec G28).
  static Color _color(StratumColorTokens colors, FontColor role) =>
      switch (role) {
        FontColor.brandPrimary ||
        FontColor.brandSecondary ||
        FontColor.brandTertiary => colors.text.color.brand,
        FontColor.primary => colors.text.defaults.primary,
        FontColor.primaryInverse => colors.text.defaults.primaryInverse,
        FontColor.primaryOnColor => colors.text.defaults.primaryOnColor,
        FontColor.secondary => colors.text.defaults.secondary,
        FontColor.secondaryInverse => colors.text.defaults.secondaryInverse,
        FontColor.tertiary => colors.text.defaults.tertiary,
        FontColor.tertiaryInverse => colors.text.defaults.tertiaryInverse,
      };

  static void _warnOnce(String message) {
    if (kDebugMode && _warned.add(message)) {
      debugPrint('Stratum theme: $message');
    }
  }
}
