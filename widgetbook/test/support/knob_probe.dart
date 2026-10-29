import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:stratum_ui/stratum_ui.dart';

/// Key of the probe's counter button.
const probeBumpKey = Key('probe-bump');

/// Key of the probe's `onPressed` button.
const probePressKey = Key('probe-press');

/// Key of the probe's `onChanged` button.
const probeChangeKey = Key('probe-change');

/// Key of the box the probe paints with its `customStyle`.
const probeStyledKey = Key('probe-styled');

/// A test-only widget with one param of each kind the knob rules cover: a
/// `Widget? slot`, an `onPressed`, an `onChanged`, a `customStyle`, a
/// `label`, and a counter in its `State`.
class KnobProbe extends StatefulWidget {
  const KnobProbe({
    super.key,
    this.slot,
    this.onPressed,
    this.onChanged,
    this.customStyle,
    this.label,
  });

  final Widget? slot;
  final VoidCallback? onPressed;
  final ValueChanged<String>? onChanged;
  final WidgetStyle? customStyle;
  final String? label;

  @override
  State<KnobProbe> createState() => _KnobProbeState();
}

class _KnobProbeState extends State<KnobProbe> {
  int _count = 0;

  @override
  Widget build(BuildContext context) => ColumnLayout(
    children: [
      ?widget.slot,
      if (widget.label != null) Text(widget.label!),
      GestureDetector(
        key: probeBumpKey,
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _count++),
        child: Text('count $_count'),
      ),
      GestureDetector(
        key: probePressKey,
        behavior: HitTestBehavior.opaque,
        onTap: widget.onPressed,
        child: const Text('press'),
      ),
      GestureDetector(
        key: probeChangeKey,
        behavior: HitTestBehavior.opaque,
        onTap: () => widget.onChanged?.call('x'),
        child: const Text('change'),
      ),
      ContainerLayout(key: probeStyledKey, style: widget.customStyle),
    ],
  );
}

/// Wraps [child] in a `MaterialApp` showing [locale].
Widget probeApp({required Widget child, Locale locale = const Locale('en')}) =>
    MaterialApp(
      locale: locale,
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const [Locale('en'), Locale('th')],
      home: Scaffold(body: child),
    );
