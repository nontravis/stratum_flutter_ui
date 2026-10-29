import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/stratum_ui.dart';
import 'package:stratum_ui_widgetbook/layout/layout_page.dart';

import '../support/catalog_theme.dart';

void main() {
  testWidgets(
    'fo11/us06/fr01: the scroll focus ring draws at the theme\'s focus '
    'width, not a fixed one',
    (tester) async {
      final themes = await loadDefaultThemeSet();
      late ScrollFocusStyle? style;
      late double tokenWidth;
      await tester.pumpWidget(
        MaterialApp(
          home: StratumThemeApplication(
            themes: themes,
            themeMode: ThemeMode.light,
            child: Builder(
              builder: (context) {
                tokenWidth = context.theme.focus.outsideWidth;
                style = scrollFocusStylePresets[1].build(context);
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      expect(scrollFocusStylePresets[1].name, 'Gray ring');
      expect(style?.focus?.width?.resolve({}), tokenWidth);
    },
  );
}
