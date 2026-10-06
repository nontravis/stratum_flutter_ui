import 'package:stratum_ui/src/themes/config/pipeline/check_keys.dart';
import 'package:stratum_ui/src/themes/config/pipeline/load.dart';
import 'package:stratum_ui/src/themes/config/pipeline/merge.dart';
import 'package:stratum_ui/src/themes/config/pipeline/read_values.dart';
import 'package:stratum_ui/src/themes/config/pipeline/resolve_aliases.dart';
import 'package:stratum_ui/src/themes/config/plain_theme_config.dart';
import 'package:stratum_ui/src/themes/config/reader.dart';
import 'package:stratum_ui/src/themes/config/theme_source.dart';

/// Runs the five stages of spec section 7 on [base], the package default
/// theme, and [layers] in merge order, in Dart with no Flutter (FO-01 s01
/// Theme config pipeline): load and check `$schema`, check keys, merge,
/// resolve aliases, read plain values. [googleFontExists] answers whether
/// a Google Fonts family exists (plan D-j).
///
/// Synchronous; reads no file. Throws one `StratumThemeFormatException`
/// that lists every problem.
PlainThemeConfig parseThemeValues({
  required StratumThemeSource base,
  List<StratumThemeSource> layers = const [],
  required bool Function(String name) googleFontExists,
}) {
  final sources = [base, ...layers];
  final errors = ThemeErrors([for (final source in sources) source.id]);
  final roots = loadThemes(sources, errors);
  errors.throwIfAny();
  final checked = checkThemeKeys(roots, errors);
  final merged = mergeThemes(checked, errors);
  final resolved = resolveThemeAliases(merged, checked.schema, errors);
  final values = readThemeValues(
    resolved,
    checked.schema,
    sources,
    errors,
    googleFontExists: googleFontExists,
  );
  errors.throwIfAny();
  return values;
}
