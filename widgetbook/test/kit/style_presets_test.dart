import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/stratum_ui.dart';
import 'package:stratum_ui_widgetbook/kit/style_presets.dart';

import '../support/catalog_theme.dart';

void main() {
  testWidgets('fo11/us06/fr01: the style presets are None, Card, Outlined, '
      'Padded', (tester) async {
    expect(widgetStylePresets.map((preset) => preset.name), [
      'None',
      'Card',
      'Outlined',
      'Padded',
    ]);

    late List<WidgetStyle?> styles;
    late StratumTheme theme;
    final themes = await loadDefaultThemeSet();
    await tester.pumpWidget(
      MaterialApp(
        home: StratumThemeApplication(
          themes: themes,
          themeMode: ThemeMode.light,
          child: Builder(
            builder: (context) {
              theme = context.theme;
              styles = [
                for (final preset in widgetStylePresets) preset.build(context),
              ];
              return const SizedBox();
            },
          ),
        ),
      ),
    );

    expect(styles[0], isNull);
    expect(styles[1]?.backgroundColor, theme.color.background.color.gray);
    expect(styles[1]?.borderRadius, BorderRadius.circular(theme.radius.lg));
    expect(styles[1]?.padding, EdgeInsets.all(theme.space.md));
    expect(styles[2]?.border, Border.all(color: theme.color.border.color.gray));
    expect(styles[2]?.borderRadius, BorderRadius.circular(theme.radius.lg));
    expect(styles[2]?.backgroundColor, isNull);
    expect(styles[3]?.padding, EdgeInsets.all(theme.space.md));
    expect(styles[3]?.backgroundColor, isNull);
  });
}
