import 'package:flutter/material.dart';
import 'package:flutter_falmodel/flutter_falmodel.dart' show FullWidgetState;
import 'package:stratum_ui/src/components/common/base/widget_props.dart';
import 'package:stratum_ui/src/components/common/model/widget_style.dart';
import 'package:stratum_ui/src/themes/constant/color.dart';
import 'package:stratum_ui/src/themes/constant/feedback_state.dart';
import 'package:stratum_ui/src/themes/constant/widget_size.dart';
import 'package:stratum_ui/src/themes/constant/window_size.dart';

/// Base class for a Stratum component with state, such as the hovered,
/// pressed, and focused states it derives at runtime.
///
/// Holds the props of [StratumWidgetProps]; the `State` reads them through
/// `widget`, for example `widget.resolveSize(context)`.
abstract class StratumStatefulWidget extends StatefulWidget
    with StratumWidgetProps {
  const new({
    super.key,
    this.size,
    this.color,
    this.themeMode,
    this.windowSize,
    this.state = FullWidgetState.normal,
    this.feedbackState,
    this.disabled = false,
    this.loading = false,
    this.debug = false,
    this.customStyle,
  });

  @override
  final WidgetSize? size;
  @override
  final ColorEnum? color;
  @override
  final ThemeMode? themeMode;
  @override
  final WindowSize? windowSize;
  @override
  final FullWidgetState state;
  @override
  final FeedbackState? feedbackState;
  @override
  final bool disabled;
  @override
  final bool loading;
  @override
  final bool debug;
  @override
  final WidgetStyle? customStyle;
}
