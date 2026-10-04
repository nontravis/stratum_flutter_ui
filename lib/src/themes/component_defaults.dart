import 'package:stratum_ui/src/src.dart';

/// Builds one default style per component type from the active theme
/// (spec section 7.9).
typedef StratumComponentDefaultsBuilder = Map<Type, WidgetStyle> Function(
  StratumTheme theme,
);

/// The app-wide component defaults (L2) the application publishes. The
/// customization order belongs to FO-08 US-06 FR-01.
class StratumComponentDefaults extends InheritedWidget {
  const new({super.key, required this.styles, required super.child});

  /// One default style per exact component type.
  final Map<Type, WidgetStyle> styles;

  /// The app-wide default style of component type [T]; null when the app
  /// registers none for [T] or no application is above [context].
  static WidgetStyle? of<T>(BuildContext context) => styleOf(context, T);

  /// [of] for a type known at run time, such as a component's
  /// `runtimeType`.
  static WidgetStyle? styleOf(BuildContext context, Type type) => context
      .dependOnInheritedWidgetOfExactType<StratumComponentDefaults>()
      ?.styles[type];

  /// Compares the maps by value, so a builder that returns an equal map
  /// rebuilds no component.
  @override
  bool updateShouldNotify(StratumComponentDefaults oldWidget) =>
      !mapEquals(styles, oldWidget.styles);
}
