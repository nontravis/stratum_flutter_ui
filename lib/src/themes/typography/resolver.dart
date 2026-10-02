import 'package:stratum_ui/src/src.dart';

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
    final style = typography.types[type];
    if (style == null) {
      throw StateError('No style for type "${type.name}".');
    }
    final base = recipe.customSize ?? recipe.fontSize.value;
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

    final scaleDimension = windowSize == null
        ? null
        : style.scaleByWindowSize?[windowSize] ??
              typography.scaleByWindowSize[windowSize];
    final size = base + (scaleDimension?.resolve(of: base) ?? 0);
    final fontSize = size + font.adjustSize.resolve(of: base);
    final scaledBase = textScaler.scale(base);
    final lineBox = scaledBase + metrics.spaceHeight.resolve(of: scaledBase);
    final fallback = _fallback(typography, type, mono, font.qualifiedFamily);

    return TextStyle(
      color: recipe.customColor ?? _color(theme.color, recipe.colorRole),
      fontSize: fontSize,
      fontWeight: recipe.fontWeight ?? style.weight,
      fontStyle: recipe.fontStyle,
      letterSpacing: metrics.letterSpacing.resolve(of: textScaler.scale(size)),
      height: lineBox / textScaler.scale(fontSize),
      leadingDistribution: TextLeadingDistribution.even,
      fontFamily: font.qualifiedFamily,
      fontFamilyFallback: fallback.isEmpty ? null : fallback,
      fontFeatures: style.tabular ? const [FontFeature.tabularFigures()] : null,
      decoration: recipe.textDecoration,
      shadows: recipe.textShadows,
    );
  }

  /// The metrics of the requested size, else of the nearest defined size.
  static StratumSizeMetrics _metrics(
    StratumTypeStyle style,
    StratumTextStyle recipe,
  ) {
    final custom = recipe.customSize;
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

  /// The defined size closest to [target], the smaller one on a tie.
  static FontSize _nearest(
    StratumTypeStyle style,
    double target,
    FontType type,
  ) {
    if (style.sizes.isEmpty) {
      throw StateError('No sizes for type "${type.name}".');
    }
    return style.sizes.keys.reduce((best, size) {
      final distance = (size.value - target).abs();
      final bestDistance = (best.value - target).abs();
      return distance < bestDistance ||
              (distance == bestDistance && size.value < best.value)
          ? size
          : best;
    });
  }

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

  /// [type], then each type it extends.
  static Iterable<FontType> _lineage(
    StratumTypography typography,
    FontType type,
  ) sync* {
    final seen = <FontType>{};
    for (FontType? link = type; link != null && seen.add(link);) {
      yield link;
      link = typography.types[link]?.extendsType;
    }
  }

  /// The font of [type] in [family], walking `extends`, or null.
  static StratumFontRef? _ref(
    StratumTypography typography,
    StratumFamilySet family,
    FontType type,
  ) {
    for (final link in _lineage(typography, type)) {
      if (family.types[link] case final ref?) return ref;
    }
    return null;
  }

  /// The mono font of [type] in [family]: the type's own mono, else the
  /// tag's theme-wide mono, or null.
  static String? _monoOf(
    StratumTypography typography,
    StratumFamilySet family,
    FontType type,
  ) {
    for (final link in _lineage(typography, type)) {
      if (family.types[link]?.mono case final mono?) return mono;
    }
    return family.mono;
  }

  static String _fontKey(
    StratumTypography typography,
    FontType type,
    List<StratumFamilySet> tags,
  ) {
    for (final family in tags) {
      if (_ref(typography, family, type) case final ref?) return ref.font;
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
      for (final link in _lineage(typography, type)) {
        if (family.types[link]?.mono case final mono?) return mono;
      }
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

  /// The qualified families of [type] in every tag, `default` first, then
  /// yaml order; the mono font before the font when [mono] is set; without
  /// duplicates or [primaryFamily].
  static List<String> _fallback(
    StratumTypography typography,
    FontType type,
    bool mono,
    String primaryFamily,
  ) {
    final families = [
      ?typography.families['default'],
      for (final MapEntry(:key, :value) in typography.families.entries)
        if (key != 'default') value,
    ];
    final keys = <String>{
      for (final family in families) ...[
        if (mono) ?_monoOf(typography, family, type),
        ?_ref(typography, family, type)?.font,
      ],
    };
    final qualifieds = <String>{
      for (final key in keys) typography.fonts[key]!.qualifiedFamily,
    }..remove(primaryFamily);
    return qualifieds.toList();
  }

  static Color _color(BaseThemeColor colors, FontColor role) => switch (role) {
    FontColor.brandPrimary => colors.brandPrimaryText,
    FontColor.brandSecondary => colors.brandSecondaryText,
    FontColor.brandTertiary => colors.brandTertiaryText,
    FontColor.primary => colors.textPrimary,
    FontColor.primaryInverse => colors.textPrimaryInverse,
    FontColor.primaryOnColor => colors.textPrimaryOnColor,
    FontColor.secondary => colors.textSecondary,
    FontColor.secondaryInverse => colors.textSecondaryInverse,
    FontColor.tertiary => colors.textTertiary,
    FontColor.tertiaryInverse => colors.textTertiaryInverse,
  };

  static void _warnOnce(String message) {
    if (kDebugMode && _warned.add(message)) {
      debugPrint('Stratum theme: $message');
    }
  }
}
