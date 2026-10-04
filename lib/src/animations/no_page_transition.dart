import 'package:stratum_ui/src/src.dart';

class NoPageTransition extends MaterialPageRoute<dynamic> {
  new({
    required super.builder,
    super.settings,
    super.maintainState,
    super.fullscreenDialog,
  });

  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation, Widget child) {
    return child;
  }
}
