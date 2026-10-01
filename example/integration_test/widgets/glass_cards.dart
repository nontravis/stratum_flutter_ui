// ignore_for_file: implementation_imports
import 'package:stratum_ui/src/src.dart';

import '../perf/perf_kit.dart';

/// S5: 20 glass cards in one [BackdropGroup] over a painted background.
class GlassCards extends StatelessWidget {
  const new({super.key, required this.kit});

  /// The layouts the cards draw with.
  final PerfKit kit;

  static const _glass = WidgetStyle(
    height: 120,
    margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    backgroundColor: Color(0x33FFFFFF),
    borderRadius: BorderRadius.all(Radius.circular(16)),
    backgroundBlur: ImageBlurFilter(sigmaX: 12, sigmaY: 12),
  );

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(child: CustomPaint(painter: _Stripes())),
        BackdropGroup(
          child: ListView.builder(
            itemCount: 20,
            itemBuilder: (context, index) =>
                kit.container(style: _glass, child: Text('Card $index')),
          ),
        ),
      ],
    );
  }
}

class _Stripes extends CustomPainter {
  const new();

  @override
  void paint(Canvas canvas, Size size) {
    const colors = [
      Color(0xFFE53935),
      Color(0xFF43A047),
      Color(0xFF1E88E5),
      Color(0xFFFDD835),
    ];
    final paint = Paint()..strokeWidth = 24;
    for (var x = -size.height; x < size.width; x += 32) {
      paint.color = colors[(x ~/ 32) % colors.length];
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height, 0),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_Stripes oldDelegate) => false;
}
