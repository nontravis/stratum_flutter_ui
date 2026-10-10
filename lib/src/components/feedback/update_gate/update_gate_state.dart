import 'package:stratum_ui/src/src.dart';

/// What [StratumUpdateGate] asks its builder to show.
sealed class UpdateGateState {
  const new({required this.checking});

  /// Whether an ask the gate started on a return to the foreground or on
  /// a retry runs; the shown screen stays until that ask answers or
  /// fails.
  final bool checking;
}

/// The app's force update screen: no way on to the app.
final class UpdateGateRequired extends UpdateGateState {
  const new({super.checking = false});
}

/// The app's maintenance screen, whose [retry] asks again.
final class UpdateGateMaintenance extends UpdateGateState {
  const new({required this.retry, super.checking = false});

  /// Asks the checker again; does nothing while an ask runs.
  final VoidCallback retry;
}

/// The app's update dialog over the app, shown once per gate lifetime.
final class UpdateGateAvailable extends UpdateGateState {
  const new({required this.dismiss, super.checking = false});

  /// Closes the dialog; Esc and the Android back button call it too.
  final VoidCallback dismiss;
}
