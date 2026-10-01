// ignore_for_file: implementation_imports
import 'package:stratum_ui/src/src.dart';

import '../perf/perf_kit.dart';

/// S4: 50 boxes that toggle their style every 250 ms, as long as their
/// animation, so every traced frame animates.
class AnimatingBoxes extends StatefulWidget {
  const new({super.key, required this.kit});

  /// The layouts the boxes draw with.
  final PerfKit kit;

  @override
  State<AnimatingBoxes> createState() => _AnimatingBoxesState();
}

class _AnimatingBoxesState extends State<AnimatingBoxes> {
  static const _a = WidgetStyle(
    width: 48,
    height: 48,
    backgroundColor: Color(0xFF2962FF),
    borderRadius: BorderRadius.all(Radius.circular(4)),
    animationStyle: AnimationStyle(duration: Duration(milliseconds: 250)),
  );
  static const _b = WidgetStyle(
    width: 64,
    height: 64,
    backgroundColor: Color(0xFFFF6D00),
    borderRadius: BorderRadius.all(Radius.circular(32)),
    dropShadow: [BoxShadow(color: Color(0x44000000), blurRadius: 12)],
    animationStyle: AnimationStyle(duration: Duration(milliseconds: 250)),
  );

  late final Timer _timer;
  var _flip = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(
      const Duration(milliseconds: 250),
      (_) => setState(() => _flip = !_flip),
    );
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var i = 0; i < 50; i++)
          widget.kit.container(style: (i.isEven ^ _flip) ? _a : _b),
      ],
    );
  }
}
