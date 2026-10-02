import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';

import '../components/common/fakes/fake_stratum_theme.dart';

StratumThemeData _theme(StratumTypography typography) => StratumThemeData(
  defaultWidgetSize: WidgetSize.medium,
  themeMode: ThemeMode.light,
  color: fakeTheme.color,
  borderRadius: const AppRadius(),
  border: const AppBorder(),
  shadow: const AppShadow(),
  size: const AppSize(),
  filter: const AppFilter(),
  systemOverlayStyle: SystemUiOverlayStyle.dark,
  systemOverlayInverseStyle: SystemUiOverlayStyle.light,
  space: const AppSpace(),
  splashFactory: InkRipple.splashFactory,
  typography: typography,
);

void main() {
  const inter = StratumTypography(
    fonts: {'inter': StratumFontData(family: 'Inter')},
    families: {},
    types: {},
  );
  const geist = StratumTypography(
    fonts: {'geist': StratumFontData(family: 'Geist')},
    families: {},
    types: {},
  );

  test('copyWith keeps the typography unless it is given', () {
    final theme = _theme(inter);

    expect(theme.typography, inter);
    expect(theme.copyWith().typography, inter);
    expect(theme.copyWith(typography: geist).typography, geist);
  });
}
