import 'package:stratum_ui/src/src.dart';
class WidgetPerformanceMonitor extends StatefulWidget {
  const WidgetPerformanceMonitor({
    super.key,
    required this.child,
    this.debug = true,
    this.debugColor = Colors.red,
    this.name,
  });

  final bool debug;
  final Widget child;
  final Color debugColor;
  final String? name;

  @override
  State<WidgetPerformanceMonitor> createState() =>
      _WidgetPerformanceMonitorState();
}

class _WidgetPerformanceMonitorState extends State<WidgetPerformanceMonitor> {
  int buildCount = 0;
  DateTime? lastBuildTime;

  @override
  Widget build(BuildContext context) {
    if (widget.debug && kDebugMode) {
      buildCount++;
      final now = DateTime.now();
      final timeSinceLastBuild = lastBuildTime != null
          ? now.difference(lastBuildTime!).inMilliseconds
          : 0;
      lastBuildTime = now;

      debugPrint('${widget.name ?? widget.runtimeType} - Build #$buildCount, '
          'Time since last build: ${timeSinceLastBuild}ms');
      return Container(
        decoration: BoxDecoration(
          border: Border.all(color: widget.debugColor, width: 1),
        ),
        child: widget.child,
      );
    }

    return widget.child;
  }
}
