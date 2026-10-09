import 'package:flutter/widgets.dart';
import 'package:stratum_ui/src/components/common/l10n/stratum_labels.dart';

/// Stratum's built-in labels in the language of [context]'s locale: the
/// nearest [Localizations] locale, else the view's platform locale.
///
/// Reads English for a language the table does not hold (FO-09 US-01
/// FR-01). Internal: no barrel exports this file.
StratumLabels builtInLabelsOf(BuildContext context) {
  return builtInLabelsFor(
    Localizations.maybeLocaleOf(context) ??
        View.of(context).platformDispatcher.locale,
  );
}

/// Stratum's built-in labels for [locale]'s language, matched by
/// [Locale.languageCode] case-insensitively, else English.
///
/// Never hands [lookupStratumLabels] a language it does not hold, since
/// that generated lookup throws for one.
StratumLabels builtInLabelsFor(Locale locale) {
  final languageCode = locale.languageCode.toLowerCase();
  final held = StratumLabels.supportedLocales.any(
    (supported) => supported.languageCode == languageCode,
  );
  return lookupStratumLabels(Locale(held ? languageCode : 'en'));
}
