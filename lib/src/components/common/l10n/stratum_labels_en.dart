// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'stratum_labels.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class StratumLabelsEn extends StratumLabels {
  StratumLabelsEn([String locale = 'en']) : super(locale);

  @override
  String get closeButtonLabel => 'Close';

  @override
  String get expanded => 'Expanded';

  @override
  String get collapsed => 'Collapsed';

  @override
  String get removeTagLabel => 'Remove';

  @override
  String get loadingLabel => 'Loading';

  @override
  String get requiredMarker => 'Required';

  @override
  String get showMenuLabel => 'Show menu';

  @override
  String get retryLabel => 'Retry';

  @override
  String get failureMessage => 'Something went wrong';

  @override
  String get placeholderPageTitle => 'Coming soon';
}
