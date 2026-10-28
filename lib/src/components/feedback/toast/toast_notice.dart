import 'package:flutter/widgets.dart';
import 'package:stratum_ui/src/components/common/model/toast/stratum_toast_notice.dart';

/// Builds the look of one notice, replacing the plain look only: placement,
/// queue, timers, close paths, and the announcement stay the host's
/// (US-01 FR-06 E04, s03 INV-13).
typedef StratumToastBuilder = Widget Function(
  BuildContext context,
  StratumToastNotice notice,
);
