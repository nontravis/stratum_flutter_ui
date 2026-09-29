import 'package:stratum_ui/src/src.dart';

extension StratumThemeContextExtension on BuildContext {
  StratumThemeData get theme => StratumThemeApplication.of(this);

  StratumThemeData getTheme([ThemeMode? mode]) =>
      StratumThemeApplication.of(this, themeMode: mode);

  void clearFocus() => FocusScope.of(this).unfocus();

  void requestScopeFocus() => FocusScope.of(this).requestScopeFocus();

  void requestFocus([FocusNode? node]) =>
      FocusScope.of(this).requestFocus(node);
}
