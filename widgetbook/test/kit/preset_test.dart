import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/stratum_ui.dart';
import 'package:stratum_ui_widgetbook/kit/preset.dart';
import 'package:stratum_ui_widgetbook/kit/sample_text.dart';
import 'package:widgetbook/widgetbook.dart' hide ThemeMode;

import '../support/knob_probe.dart';

const _filled = Color(0xFF123456);
const _outlined = Color(0xFF654321);

final _presets = <Preset<WidgetStyle>>[
  const Preset('None', _none),
  Preset(
    'Filled',
    (context) =>
        const WidgetStyle(width: 40, height: 40, backgroundColor: _filled),
  ),
  Preset(
    'Outlined',
    (context) =>
        const WidgetStyle(width: 40, height: 40, backgroundColor: _outlined),
  ),
];

WidgetStyle? _none(BuildContext context) => null;

/// Pumps the probe with the style [preset] picked.
Future<void> _pump(WidgetTester tester, Preset<WidgetStyle> preset) =>
    tester.pumpWidget(
      probeApp(
        child: Builder(
          builder: (context) => KnobProbe(customStyle: preset.build(context)),
        ),
      ),
    );

Color? _paintedColor(WidgetTester tester) => tester
    .widget<ContainerLayout>(find.byKey(probeStyledKey))
    .style
    ?.backgroundColor;

void main() {
  testWidgets('fo11/us04/fr04, fo11/us04/s4: a style preset restyles the '
      'probe', (tester) async {
    final arg = PresetArg<WidgetStyle>(_presets.first, values: _presets);

    expect(arg.fields, hasLength(1));
    expect(arg.fields.single, isA<ObjectDropdownField<Preset<WidgetStyle>>>());

    await _pump(tester, _presets.first);
    expect(_paintedColor(tester), isNull);

    await _pump(tester, _presets[1]);
    expect(_paintedColor(tester), _filled);
  });

  testWidgets('fo11/us04/fr04/e01: another preset renders again with its '
      'style', (tester) async {
    await _pump(tester, _presets[1]);
    expect(_paintedColor(tester), _filled);

    await _pump(tester, _presets[2]);

    expect(_paintedColor(tester), _outlined);
  });

  test('fo11/us04/fr04: the query value of a preset is its name', () {
    final arg = PresetArg<WidgetStyle>(_presets.first, values: _presets);
    final field = arg.fields.single as ObjectDropdownField<Preset<WidgetStyle>>;

    expect(field.labelBuilder(_presets[1]), 'Filled');
    expect(arg.valueToQueryGroup(_presets[2]).toParam(), contains('Outlined'));
  });

  testWidgets('fo11/us04/fr05: a preset reads the locale through its '
      'context', (tester) async {
    final preset = Preset<String>(
      'Label',
      (context) => SampleTexts.label.resolve(Localizations.localeOf(context)),
    );
    late String shown;
    await tester.pumpWidget(
      probeApp(
        locale: const Locale('th'),
        child: Builder(
          builder: (context) {
            shown = preset.build(context)!;
            return Text(shown);
          },
        ),
      ),
    );

    expect(shown, SampleTexts.label.th);
  });
}
