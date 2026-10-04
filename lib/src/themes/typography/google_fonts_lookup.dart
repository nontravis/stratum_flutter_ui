import 'package:stratum_ui/src/src.dart';

/// Test seam for the three `GoogleFonts` calls a `google` font (see
/// `StratumFontSource`) needs.
///
/// Replace [exists], [family], or [pending] in a test and restore them in
/// `tearDown`; no test calls `GoogleFonts.getFont` for real, since it
/// starts an HTTP fetch. A parse test may keep the real [exists] default:
/// it reads `GoogleFonts.asMap()`, a const map with no network. Production
/// code may only read [exists], [family], and [pending]; only a test may
/// replace them.
///
/// Deliberately kept out of `lib/src/themes/themes.dart` and every barrel
/// it feeds, so the public `package:stratum_ui/stratum_ui.dart` export
/// never exposes these setters to an app: `typography.dart`,
/// `resolver.dart`, `theme_controller.dart`, and their tests import this
/// file directly with a package import instead of reaching it through a
/// barrel.
abstract final class GoogleFontsLookup {
  static bool Function(String name) _exists = (name) =>
      GoogleFonts.asMap().containsKey(name);

  static String Function(
    String name, {
    required FontWeight weight,
    required FontStyle? style,
  })
  _family = (name, {required weight, required style}) => GoogleFonts.getFont(
    name,
    fontWeight: weight,
    fontStyle: style,
  ).fontFamily!;

  /// Whether `GoogleFonts.asMap()` has an entry for the given Google Fonts
  /// family name; case-sensitive.
  static bool Function(String name) get exists => _exists;

  @visibleForTesting
  static set exists(bool Function(String name) value) => _exists = value;

  /// The family `GoogleFonts.getFont(name, fontWeight: weight, fontStyle:
  /// style).fontFamily` resolves.
  static String Function(
    String name, {
    required FontWeight weight,
    required FontStyle? style,
  })
  get family => _family;

  @visibleForTesting
  static set family(
    String Function(
      String name, {
      required FontWeight weight,
      required FontStyle? style,
    })
    value,
  ) => _family = value;

  static Future<void> Function() _pending = GoogleFonts.pendingFonts;

  /// Completes once every Google font the app asked for has loaded or
  /// failed: `GoogleFonts.pendingFonts()`.
  static Future<void> Function() get pending => _pending;

  @visibleForTesting
  static set pending(Future<void> Function() value) => _pending = value;
}
