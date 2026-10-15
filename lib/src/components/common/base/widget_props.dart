import 'package:flutter/material.dart';
import 'package:flutter_falmodel/flutter_falmodel.dart' show FullWidgetState;
import 'package:stratum_ui/src/components/common/model/widget_style.dart';
import 'package:stratum_ui/src/extensions/context_extension.dart';
import 'package:stratum_ui/src/themes/component_defaults.dart';
import 'package:stratum_ui/src/themes/constant/color.dart';
import 'package:stratum_ui/src/themes/constant/feedback_state.dart';
import 'package:stratum_ui/src/themes/constant/widget_size.dart';
import 'package:stratum_ui/src/themes/constant/window_size.dart';
import 'package:stratum_ui/src/themes/theme_application.dart';
import 'package:stratum_ui/src/themes/theme_data.dart';
import 'package:stratum_ui/src/themes/tokens/theme_tokens.g.dart';

/// The props every Stratum component takes, and how they resolve.
///
/// Call the `resolve*` methods inside `build` only: they register
/// dependencies on the nearest [StratumThemeApplication] and
/// `WindowSizeScope`.
mixin StratumWidgetProps {
  /// Null resolves to the theme's `defaultWidgetSize`.
  WidgetSize? get size;

  /// Feedback colors go to [feedbackState] instead.
  ColorEnum? get color;

  /// Null uses the app's theme mode.
  ThemeMode? get themeMode;

  /// Null resolves from the nearest `WindowSizeScope`.
  WindowSize? get windowSize;

  /// Forces a visual state for previews and golden tests. When it is
  /// `normal`, the widget derives hovered, pressed, and focused at runtime.
  ///
  /// Holds interaction values only: `normal`, `hovered`, `pressed`,
  /// `focused`, and `dragged`. Use [disabled] and [loading], not
  /// `FullWidgetState.disabled` or `FullWidgetState.loading`.
  FullWidgetState get state;

  /// The feedback tone (`info`, `negative`, `warning`, `positive`); null
  /// shows none.
  FeedbackState? get feedbackState;

  /// Shows the disabled state: the base dims the component, shows the
  /// forbidden cursor, refuses its pointer and focus input, and reports it
  /// disabled (FO-08 US-07); each component decides which look wins inside.
  bool get disabled;

  /// Shows the loading state, such as an indeterminate spinner.
  bool get loading;

  /// The highest layer of [resolveStyle].
  WidgetStyle? get customStyle;

  /// Throws a [FlutterError] when no [StratumThemeApplication] is above
  /// [context].
  StratumThemeData resolveTheme(BuildContext context) =>
      context.themeData(themeMode);

  /// Returns [size] when set, else the default widget size of
  /// [resolveTheme]; a subclass that overrides [resolveTheme] sets its
  /// default size this way. A null [size] reads the theme, so it throws
  /// like [resolveTheme] when no theme is above [context].
  WidgetSize resolveDefaultSize(BuildContext context) =>
      size ?? resolveTheme(context).defaultWidgetSize;

  /// Renamed to [resolveDefaultSize]; kept one minor version.
  @Deprecated('Use resolveDefaultSize. Removed after one minor version.')
  WidgetSize resolveSize(BuildContext context) => resolveDefaultSize(context);

  /// Throws a [FlutterError] when [windowSize] is null and no
  /// `WindowSizeScope` is above [context].
  WindowSize resolveWindowSize(BuildContext context) =>
      windowSize ?? context.windowSize;

  /// [defaults] (the component's own style from theme tokens), then the
  /// app-wide default for this component's exact `runtimeType`, then
  /// [customStyle], in the order FO-08 US-06 FR-01 owns; each layer
  /// replaces only the fields it sets. The FO-08 L4 subclass default
  /// style is not a layer yet.
  WidgetStyle resolveStyle(BuildContext context, WidgetStyle defaults) =>
      defaults
          .merge(StratumComponentDefaults.styleOf(context, runtimeType))
          .merge(customStyle);

  /// The token named [color] in the `<group>.color` group that [group]
  /// picks from the resolved theme's colors, such as
  /// `(colors) => colors.icon.color`; [fallback], the component's own
  /// default color of that group, when [color] is null or the group holds
  /// no token of that name (FO-08 US-01 FR-03).
  ///
  /// A null [color] reads no theme, so it never throws; a set [color]
  /// throws like [resolveTheme] when no theme is above [context].
  Color resolveColor(
    BuildContext context,
    StratumColorEnumTokens Function(StratumColorTokens colors) group,
    Color fallback,
  ) {
    final name = color;
    if (name == null) return fallback;
    return group(resolveTheme(context).color)[name] ?? fallback;
  }
}
