import 'package:stratum_ui/src/src.dart';

class StratumThemeApplication extends InheritedWidget {
  const new({
    super.key,
    required this.themeMode,
    required this.lightTheme,
    required this.darkTheme,
    required super.child,
  });

  final ThemeMode themeMode;
  final StratumThemeData lightTheme;
  final StratumThemeData? darkTheme;

  static StratumThemeData of(BuildContext context, {ThemeMode? themeMode}) {
    final theme = context
        .dependOnInheritedWidgetOfExactType<StratumThemeApplication>();
    if (theme == null) {
      throw FlutterError(
        'StratumThemeApplication.of() called with a context that does not contain a '
        'StratumThemeApplication.',
      );
    }

    final tmpThemeMode = themeMode ?? theme.themeMode;
    if (tmpThemeMode == ThemeMode.system) {
      final brightness = MediaQuery.of(context).platformBrightness;
      final isDarkMode = brightness == Brightness.dark;
      return isDarkMode
          ? (theme.darkTheme ?? theme.lightTheme)
          : theme.lightTheme;
    } else {
      return tmpThemeMode == ThemeMode.dark
          ? (theme.darkTheme ?? theme.lightTheme)
          : theme.lightTheme;
    }
  }

  // Helper method to wrap widgets that need theme access
  static Widget wrap(BuildContext context, {required Widget child}) {
    final theme = context
        .dependOnInheritedWidgetOfExactType<StratumThemeApplication>();
    if (theme == null) {
      return child;
    }

    return StratumThemeApplication(
      themeMode: theme.themeMode,
      lightTheme: theme.lightTheme,
      darkTheme: theme.darkTheme,
      child: child,
    );
  }

  @override
  bool updateShouldNotify(covariant StratumThemeApplication oldWidget) {
    return lightTheme != oldWidget.lightTheme;
  }
}

extension AppStratumThemeApplicationExtensions on ThemeMode {
  StratumThemeData theme(BuildContext context) {
    return StratumThemeApplication.of(context, themeMode: this);
  }
}
