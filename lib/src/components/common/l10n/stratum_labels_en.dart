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
  String get placeholderPageTitle => 'Coming soon';

  @override
  String reorderMoveAnnouncement(int position, int count) {
    return 'Moved to position $position of $count';
  }

  @override
  String get reorderAtStartAnnouncement => 'Already at the start of the list';

  @override
  String get reorderAtEndAnnouncement => 'Already at the end of the list';

  @override
  String get drawerLabel => 'Navigation menu';

  @override
  String get dismissLabel => 'Dismiss';

  @override
  String get dialogLabel => 'Dialog';

  @override
  String get sheetLabel => 'Sheet';

  @override
  String get dividerLabel => 'Resize panes';

  @override
  String get noticePositiveLabel => 'Success';

  @override
  String get noticeInfoLabel => 'Information';

  @override
  String get noticeWarningLabel => 'Warning';

  @override
  String get noticeNegativeLabel => 'Error';

  @override
  String noticeShortcutHint(String key) {
    return 'Press $key to reach it';
  }
}
