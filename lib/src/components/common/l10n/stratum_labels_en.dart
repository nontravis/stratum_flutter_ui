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

  @override
  String get forceUpdateTitle => 'Update required';

  @override
  String get forceUpdateMessage =>
      'Please update to the latest version to continue.';

  @override
  String get maintenanceTitle => 'Under maintenance';

  @override
  String get maintenanceMessage =>
      'We\'ll be back soon. Please try again later.';

  @override
  String get softUpdateTitle => 'Update available';

  @override
  String get softUpdateMessage =>
      'A new version is ready. Update now for the latest improvements.';

  @override
  String get updateLabel => 'Update';

  @override
  String get laterLabel => 'Later';
}
