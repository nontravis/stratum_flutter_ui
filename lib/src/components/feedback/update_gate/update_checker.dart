import 'package:stratum_ui/src/src.dart';

/// The app's update check that [StratumUpdateGate] asks (CO-05-09).
///
/// It reads every input the app needs, such as remote settings, the
/// package version, or a store version; the package calls no store,
/// plugin, or backend. Give [check] a time limit of its own: the gate
/// sets none.
abstract interface class UpdateChecker {
  /// One answer per ask. A thrown error shows the gate's child, so a
  /// broken check never locks the app; log it here.
  Future<UpdateStatus> check();
}

/// An [UpdateChecker]'s answer.
enum UpdateStatus {
  /// The app shows.
  upToDate,

  /// The app shows, and the app's dialog offers the update once per
  /// gate lifetime.
  available,

  /// The app's force update screen replaces the app, with no way on.
  required,

  /// The app's maintenance screen replaces the app, with a retry.
  maintenance,
}
