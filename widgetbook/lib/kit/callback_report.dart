import 'package:stratum_ui/stratum_ui.dart';
import 'package:widgetbook/widgetbook.dart' hide ThemeMode;

/// Shows the last callback a story reported under its [child]
/// (fo11/us04/fr03).
class CallbackReport extends StatefulWidget {
  const CallbackReport({super.key, required this.child});

  final Widget child;

  /// Shows `'$name called'` in the nearest report above [context], for a
  /// callback that a rebuild replaces.
  static void report(BuildContext context, String name) =>
      reporter(context, name)();

  /// Returns a function that shows `'$name called'` in the nearest report
  /// above [context].
  ///
  /// It looks the report up now, not when it is called, because the caller
  /// may be a notice that outlives the context after a knob change; it shows
  /// nothing once that report is gone.
  static VoidCallback reporter(BuildContext context, String name) {
    final state = context.findAncestorStateOfType<_CallbackReportState>();
    assert(state != null, 'reportCallback needs setup: reportingSetup');
    return () {
      if (state != null && state.mounted) state._show('$name called');
    };
  }

  @override
  State<CallbackReport> createState() => _CallbackReportState();
}

class _CallbackReportState extends State<CallbackReport> {
  String? _last;

  void _show(String line) => setState(() => _last = line);

  @override
  Widget build(BuildContext context) => ColumnLayout(
    mainAxisSize: MainAxisSize.min,
    children: [
      Flexible(child: widget.child),
      if (_last != null) Text(_last!),
    ],
  );
}

/// The `setup:` of every story that reports a callback.
///
/// The report sits outside Widgetbook's `KeyedSubtree`, so a knob change
/// still resets the story's state and keeps the report line (s03 INV-9).
Widget reportingSetup(
  BuildContext context,
  Widget child,
  StoryArgs<Widget> args,
) => CallbackReport(child: Story.defaultSetup(context, child, args));

/// A `VoidCallback` that reports `'$name called'`.
VoidCallback reportCallback(BuildContext context, String name) =>
    CallbackReport.reporter(context, name);

/// A `ValueChanged<T>` that reports `'$name called'`.
ValueChanged<T> reportValue<T>(BuildContext context, String name) {
  final report = CallbackReport.reporter(context, name);
  return (_) => report();
}
