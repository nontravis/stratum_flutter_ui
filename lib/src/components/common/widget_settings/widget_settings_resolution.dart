import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';
import 'package:stratum_ui/src/components/common/widget_settings/widget_settings_controller.dart';
import 'package:stratum_ui/src/components/common/widget_settings/widget_settings_scope.dart';

/// The [StratumWidgetSettingsController] a preloading wrapper uses (PD9):
/// [passed], else the scope above [context], else a fresh one over the
/// default store. The second value is true only for that fresh one,
/// which the caller then disposes with itself.
@internal
(StratumWidgetSettingsController controller, bool owned) resolveWidgetSettings(
  BuildContext context,
  StratumWidgetSettingsController? passed,
) {
  if (passed != null) return (passed, false);
  final above = StratumWidgetSettings.maybeControllerOf(context);
  if (above != null) return (above, false);
  return (StratumWidgetSettingsController(), true);
}
