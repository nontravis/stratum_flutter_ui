import 'package:flutter/material.dart';
import 'package:flutter_falmodel/flutter_falmodel.dart' show FullWidgetState;
import 'package:stratum_ui/src/components/common/base/disabled.dart';
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
/// `widget`, for example `widget.resolveDefaultSize(context)`. The
/// `State`'s `build` returns one box widget at its root, never a
/// `ParentDataWidget` (`Expanded`, `Flexible`, `Positioned`); the base's
/// element asserts this in debug builds. A sliver root is not caught by
/// this assertion; it fails Flutter's own box-child assertion instead
/// (US-07 FR-01 E07).
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
  final WidgetStyle? customStyle;

  /// Whether the base dims this component while [disabled] is true;
  /// override with `false` when the component draws its own disabled
  /// look. The forbidden cursor, refused input, focus, and screen-reader
  /// rules hold either way (FO-08 US-07 FR-04). A change to its name or
  /// type is a breaking change to a protected hook (NFR-M04).
  @protected
  bool get dimsWhenDisabled => true;

  /// Whether this component gives a screen reader something to read; the
  /// base reads it at build time. Override with `false` for a decorative
  /// component, such as a caret: while [disabled] is true it then gets no
  /// disabled semantics node, and the dimming, cursor, pointer, and focus
  /// rules still hold (FO-08 US-07 FR-03 E01). A change to its name or
  /// type is a breaking change to a protected hook (NFR-M04).
  @protected
  bool get contributesSemantics => true;

  /// An element that wraps what the `State`'s `build` returns in the
  /// disabled wrapper, so no component changes its own `build` (base s03
  /// invariant 12).
  @override
  StatefulElement createElement() => _StratumStatefulElement(this);
}

class _StratumStatefulElement extends StatefulElement {
  new(StratumStatefulWidget super.widget);

  @override
  Widget build() {
    final component = widget as StratumStatefulWidget;
    final built = super.build();
    assert(
      built is! ParentDataWidget,
      boxRootAssertionMessage(component.runtimeType, built),
    );
    return StratumDisabled(
      disabled: component.disabled,
      dims: component.dimsWhenDisabled,
      contributesSemantics: component.contributesSemantics,
      child: built,
    );
  }
}
