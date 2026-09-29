import 'package:stratum_ui/src/src.dart';

class ThemeApplication extends InheritedWidget {
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
        .dependOnInheritedWidgetOfExactType<ThemeApplication>();
    if (theme == null) {
      throw FlutterError(
        'ThemeApplication.of() called with a context that does not contain a '
        'ThemeApplication.',
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
        .dependOnInheritedWidgetOfExactType<ThemeApplication>();
    if (theme == null) {
      return child;
    }

    return ThemeApplication(
      themeMode: theme.themeMode,
      lightTheme: theme.lightTheme,
      darkTheme: theme.darkTheme,
      child: child,
    );
  }

  @override
  bool updateShouldNotify(covariant ThemeApplication oldWidget) {
    return lightTheme != oldWidget.lightTheme;
  }
}

extension AppThemeApplicationExtensions on ThemeMode {
  StratumThemeData theme(BuildContext context) {
    return ThemeApplication.of(context, themeMode: this);
  }
}
