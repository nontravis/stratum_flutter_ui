import 'package:stratum_ui/src/src.dart';

class StratumScrollBehavior extends MaterialScrollBehavior {
  const new();

  Widget buildViewportChrome(
          BuildContext context, Widget child, AxisDirection axisDirection) =>
      child;
}
