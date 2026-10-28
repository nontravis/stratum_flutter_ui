import 'package:stratum_ui/stratum_ui.dart';
import 'package:widgetbook/widgetbook.dart' hide ThemeMode;

/// Returns the language the toolbar sets.
///
/// Widgetbook shows docs with no addon applied, so a doc block reads the
/// toolbar's `LocaleAddon` from the state; outside Widgetbook it falls back
/// to the ambient [Localizations].
Locale toolbarLocale(BuildContext context) {
  final state = WidgetbookState.maybeOf(context);
  for (final addon in state?.config.addons ?? const <Addon<dynamic>>[]) {
    if (addon is LocaleAddon) {
      return addon.valueFromQueryGroup(state!.queryGroups[addon.groupName]);
    }
  }
  return Localizations.localeOf(context);
}
