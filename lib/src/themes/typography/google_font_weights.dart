import 'package:stratum_ui/src/src.dart';

/// The weights each Google font of a typography loads in: its weight set
/// (`docs/specs/stratum_ui/themes/typography/s03_domain.md` invariant 13,
/// `docs/specs/stratum_ui/themes/s03_domain.md` invariant 4).
///
/// The one home of the weight-set rule: the theme controller's Google
/// wait loads each Google font in these weights, and `TypographyResolver`
/// draws each Google font only in them, whether or not a wait ran.
///
/// Deliberately kept out of `lib/src/themes/themes.dart` and every barrel
/// it feeds, as `google_fonts_lookup.dart` is: `resolver.dart`,
/// `theme_controller.dart`, and their tests import this file directly.
abstract final class GoogleFontWeights {
  static final _sets = Expando<Map<String, Set<FontWeight>>>(
    'GoogleFontWeights sets',
  );

  /// Each Google font [typography] names, by its Google Fonts family name,
  /// to the weights it loads in: a font a tag names for a type, as `font`
  /// or `mono`, in that type's weight, `table` taking body's; every tag's
  /// `body` font and theme-wide `mono` in every type's weight.
  ///
  /// App and theme fonts are absent; two font keys of one family share one
  /// set. A type [typography] lacks adds no weight: only a hand-built
  /// typography lacks one, since the parser requires every type but
  /// `table`. Unmodifiable, and computed once per [typography] instance.
  static Map<String, Set<FontWeight>> of(StratumTypography typography) =>
      _sets[typography] ??= _compute(typography);

  static Map<String, Set<FontWeight>> _compute(StratumTypography typography) {
    FontWeight? weightOf(FontType type) =>
        typography.types[type == FontType.table ? FontType.body : type]?.weight;
    final every = {for (final type in FontType.values) ?weightOf(type)};
    final weights = <String, Set<FontWeight>>{};
    void use(String? key, Iterable<FontWeight> typeWeights) {
      final font = key == null ? null : typography.fonts[key];
      if (font == null || font.source != StratumFontSource.google) return;
      (weights[font.family] ??= {}).addAll(typeWeights);
    }

    for (final set in typography.families.values) {
      for (final type in FontType.values) {
        final weight = weightOf(type);
        if (set.types[type] case final ref?) {
          use(ref.font, [?weight]);
          use(ref.mono, [?weight]);
        }
        // The resolver draws every tag's body font as a fallback at the
        // requested type's weight (`TypographyResolver`'s fallback list),
        // even for a type the tag never names.
        use(set.types[FontType.body]?.font, [?weight]);
      }
      use(set.mono, every);
    }
    return Map<String, Set<FontWeight>>.unmodifiable({
      for (final MapEntry(:key, :value) in weights.entries)
        key: Set<FontWeight>.unmodifiable(value),
    });
  }
}
