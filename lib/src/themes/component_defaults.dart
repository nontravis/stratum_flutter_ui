import 'package:stratum_ui/src/src.dart';

/// Builds one default style per component type from the active theme
/// (spec section 7.9).
typedef StratumComponentDefaultsBuilder = Map<Type, WidgetStyle> Function(
  StratumTheme theme,
);

/// Builds one default parts style per multi-part component type from the
/// active theme (spec section 7.9; FO-03 US-06 FR-01).
typedef StratumComponentPartDefaultsBuilder = Map<Type, Object> Function(
  StratumTheme theme,
);

/// The app-wide component defaults (L2) the application publishes. The
/// customization order belongs to FO-08 US-06 FR-01.
class StratumComponentDefaults extends InheritedWidget {
  const new({
    super.key,
    required this.styles,
    this.parts = const {},
    required super.child,
  });

  /// One default style per exact component type.
  final Map<Type, WidgetStyle> styles;

  /// One parts style per exact multi-part component type, such as
  /// `ModalLayout: ModalLayoutStyle(...)`.
  final Map<Type, Object> parts;

  /// The app-wide default style of component type [T]; null when the app
  /// registers none for [T] or no application is above [context].
  static WidgetStyle? of<T>(BuildContext context) => styleOf(context, T);

  /// [of] for a type known at run time, such as a component's
  /// `runtimeType`.
  static WidgetStyle? styleOf(BuildContext context, Type type) => context
      .dependOnInheritedWidgetOfExactType<StratumComponentDefaults>()
      ?.styles[type];

  /// The app-wide parts style registered for [type]; null when no
  /// application is above [context], or none is registered for [type].
  /// Throws a [FlutterError] naming [S], [type], and the registered
  /// value's runtime type when it is not an [S] (FO-03 US-06 FR-01 E03).
  static S? partsOf<S extends Object>(BuildContext context, Type type) {
    final value = context
        .dependOnInheritedWidgetOfExactType<StratumComponentDefaults>()
        ?.parts[type];
    if (value == null) return null;
    if (value is S) return value;
    throw FlutterError(
      'StratumComponentDefaults.partsOf<$S>($type) found a '
      '${value.runtimeType}, not an $S.',
    );
  }

  /// Compares the maps by value, so a builder that returns an equal map
  /// rebuilds no component.
  @override
  bool updateShouldNotify(StratumComponentDefaults oldWidget) =>
      !mapEquals(styles, oldWidget.styles) ||
      !mapEquals(parts, oldWidget.parts);
}

/// Throws a [FlutterError] when the `componentDefaults` styles map above
/// [context] holds an entry under [component], a package component whose
/// `customStyle` is the narrower [styleType] and which reads no entry of
/// that map (FO-03 US-06 FR-01 E05; base s03 INV-21). Returns true,
/// so a caller wraps it in an `assert`. It reads the map without a
/// dependency, so it adds no rebuild.
///
/// Not exported: `themes.dart` hides it.
bool debugCheckNoComponentStyle(
  BuildContext context,
  Type component,
  Type styleType,
) {
  final style = context
      .getInheritedWidgetOfExactType<StratumComponentDefaults>()
      ?.styles[component];
  if (style == null) return true;
  throw FlutterError(
    'StratumComponentDefaults.styles holds a WidgetStyle under $component, '
    'which reads no styles-map entry: its style is $styleType. Register a '
    '$styleType under $component in componentPartDefaults instead.',
  );
}
