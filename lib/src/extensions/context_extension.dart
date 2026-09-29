import 'package:stratum_ui/src/src.dart';

extension ThemeContextExtension on BuildContext {
  StratumThemeData get theme => ThemeApplication.of(this);

  StratumThemeData getTheme([ThemeMode? mode]) =>
      ThemeApplication.of(this, themeMode: mode);

  WindowSize get windowSize => WindowSizeScope.of(this);

  void clearFocus() => FocusScope.of(this).unfocus();

  void requestScopeFocus() => FocusScope.of(this).requestScopeFocus();

  void requestFocus() => FocusScope.of(this).requestFocus();
}
