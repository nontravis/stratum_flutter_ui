import 'package:stratum_ui/src/src.dart';

extension StratumThemeContextExtension on BuildContext {
  /// `StratumTheme.of(this)`.
  StratumTheme get theme => StratumTheme.of(this);

  /// `StratumTheme.of(this, themeMode: mode)`.
  StratumTheme getTheme([ThemeMode? mode]) =>
      StratumTheme.of(this, themeMode: mode);

  void clearFocus() => FocusScope.of(this).unfocus();

  void requestScopeFocus() => FocusScope.of(this).requestScopeFocus();

  void requestFocus([FocusNode? node]) =>
      FocusScope.of(this).requestFocus(node);
}
