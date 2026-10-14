/// The notice host, the notice look builder, and the `showToast` call
/// (CO-05-07 US-01); the placement types live in the common model.
///
/// The placement helpers (`defaultToastPlacement`, `toastManagerKey`) and
/// the close-time rule (`toastCloseTime`) stay inside the toast folder;
/// tests import them by path.
library;

export 'package:stratum_ui/src/components/feedback/toast/show_toast.dart';
export 'package:stratum_ui/src/components/feedback/toast/toast_host.dart'
    hide StratumToastRequest;
export 'package:stratum_ui/src/components/feedback/toast/toast_notice.dart';
