import 'package:flutter/services.dart';
import 'package:stratum_ui/src/themes/system/system_style.dart';

/// One Stratum layer of the system bar style in the layer tree (FO-03
/// US-14; themes s03 invariants 38 to 40). Each subtype sits in an
/// `AnnotatedRegion<SystemUiOverlayStyle>`, so the resolver finds every
/// Stratum layer and a Material `AppBar`'s own annotation at a bar's point
/// in one `findAllAnnotations` call, in paint order, and every Stratum
/// layer painted anywhere by one walk of the layer tree. Its overlay
/// fields stay null; the resolver turns Flutter's own write of the overlay
/// style off for its view (themes s03 invariant 41). Internal: not
/// exported.
sealed class SystemStyleRegion extends SystemUiOverlayStyle {
  const new();
}

/// The base layer each `StratumThemeApplication` places around its child:
/// the theme data's `systemStyle` with the app-wide style merged over it,
/// and the theme's page background, which automatic icons read where no
/// fill is declared (FO-03 US-14 FR-01, FR-02). Unsized on the outermost
/// application of a view, sized to the child on a nested one; every base
/// merges under every `SystemStyleScope`.
final class SystemStyleBaseRegion extends SystemStyleRegion {
  const new({required this.style, required this.background});

  /// The look of the theme with the app-wide style over it.
  final SystemStyle style;

  /// The theme's `background.defaults.normal`.
  final Color background;

  @override
  bool operator ==(Object other) =>
      other is SystemStyleBaseRegion &&
      other.style == style &&
      other.background == background;

  @override
  int get hashCode => Object.hash(SystemStyleBaseRegion, style, background);
}

/// One half of a `SystemStyleScope`: its look, sized to its child, or its
/// behavior, unsized (themes s03 invariant 39).
final class SystemStyleLayerRegion extends SystemStyleRegion {
  const new(this.style);

  /// The look fields or the behavior fields of the scope's style.
  final SystemStyle style;

  @override
  bool operator ==(Object other) =>
      other is SystemStyleLayerRegion && other.style == style;

  @override
  int get hashCode => Object.hash(SystemStyleLayerRegion, style);
}

/// The fill a `SystemBarFill` declares, sized to its child (FO-03 US-14
/// FR-05).
final class SystemBarFillRegion extends SystemStyleRegion {
  const new(this.color);

  /// The fill, its alpha included.
  final Color color;

  @override
  bool operator ==(Object other) =>
      other is SystemBarFillRegion && other.color == color;

  @override
  int get hashCode => Object.hash(SystemBarFillRegion, color);
}
