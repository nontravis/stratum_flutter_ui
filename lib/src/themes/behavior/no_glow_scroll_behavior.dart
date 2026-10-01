import 'package:stratum_ui/src/src.dart';

class NoGlowScrollBehavior extends MaterialScrollBehavior {
  const new();

  Widget buildViewportChrome(
      BuildContext context, Widget child, AxisDirection axisDirection) =>
      child;
}
