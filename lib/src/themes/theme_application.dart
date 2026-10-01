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
    final theme = maybeOf(context, themeMode: themeMode);
    if (theme == null) {
      throw FlutterError(
        'StratumThemeApplication.of() called with a context that does not contain a '
        'StratumThemeApplication.',
      );
    }
    return theme;
  }

  /// The theme for [context], or null when no [StratumThemeApplication] is
  /// above it.
  ///
  /// In [ThemeMode.system], a missing [MediaQuery] counts as light, so this
  /// never throws.
  static StratumThemeData? maybeOf(
    BuildContext context, {
    ThemeMode? themeMode,
  }) {
    final application = context
        .dependOnInheritedWidgetOfExactType<StratumThemeApplication>();
    if (application == null) return null;
    final isDark = switch (themeMode ?? application.themeMode) {
      ThemeMode.dark => true,
      ThemeMode.light => false,
      ThemeMode.system =>
        MediaQuery.maybePlatformBrightnessOf(context) == Brightness.dark,
    };
    return isDark
        ? application.darkTheme ?? application.lightTheme
        : application.lightTheme;
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
