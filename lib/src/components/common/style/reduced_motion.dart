import 'package:flutter/widgets.dart';

/// Whether the app or the platform asks for less motion at [context].
///
/// `disableAnimations` comes from the nearest [MediaQuery], so an app or a
/// test that sets it reaches every caller, else from the platform.
/// `MediaQueryData` has no `reduceMotion` field, so that flag always comes
/// from the view's dispatcher. Not exported: `AnimatedStyledBox` and the
/// keyboard paging of a page view share this one rule.
bool reducesMotion(BuildContext context) {
  final features = View.of(context).platformDispatcher.accessibilityFeatures;
  final disable =
      MediaQuery.maybeDisableAnimationsOf(context) ??
      features.disableAnimations;
  return disable || features.reduceMotion;
}
