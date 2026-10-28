import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/stratum_ui.dart';
import 'package:stratum_ui_widgetbook/shell/catalog_config.dart';
import 'package:stratum_ui_widgetbook/shell/rtl_addon.dart';
import 'package:widgetbook/widgetbook.dart' hide ThemeMode;

import '../support/catalog_theme.dart';

typedef _Reading = ({TextDirection direction, Locale locale});

/// Reads the text direction and the locale the story sees.
class _DirectionProbe extends StatelessWidget {
  const _DirectionProbe(this.onRead);

  final ValueChanged<_Reading> onRead;

  @override
  Widget build(BuildContext context) {
    onRead((
      direction: Directionality.of(context),
      locale: Localizations.localeOf(context),
    ));
    return const SizedBox(width: 10, height: 10);
  }
}

/// Builds the locale addon at [locale] around the right-to-left addon at
/// [rtl] around a probe, the order [catalogAddons] puts them in.
Future<_Reading> _read(WidgetTester tester, Locale locale, bool rtl) async {
  final set = await loadDefaultThemeSet();
  final localeAddon = catalogAddons({'default': set})
      .whereType<LocaleAddon>()
      .single;
  late _Reading reading;
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => localeAddon.apply(
          context,
          Builder(
            builder: (context) => RtlAddon().apply(
              context,
              _DirectionProbe((value) => reading = value),
              rtl,
            ),
          ),
          locale,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return reading;
}

void main() {
  test('fo11/us02/fr02: the right-to-left addon is one boolean field', () {
    final addon = RtlAddon();

    expect(addon.name, 'Right to left');
    expect(addon.initialValue, isFalse);
    expect(addon.fields.single.name, 'enabled');
  });

  testWidgets('fo11/us02/fr02, fo11/us02/s2: right to left keeps English', (
    tester,
  ) async {
    final reading = await _read(tester, const Locale('en'), true);

    expect(reading.direction, TextDirection.rtl);
    expect(reading.locale, const Locale('en'));
  });

  testWidgets('fo11/us02/fr02/e01: right to left keeps Thai', (tester) async {
    final reading = await _read(tester, const Locale('th'), true);

    expect(reading.direction, TextDirection.rtl);
    expect(reading.locale, const Locale('th'));
  });

  testWidgets('fo11/us02/fr02: left to right stays the language default', (
    tester,
  ) async {
    final reading = await _read(tester, const Locale('th'), false);

    expect(reading.direction, TextDirection.ltr);
  });
}
