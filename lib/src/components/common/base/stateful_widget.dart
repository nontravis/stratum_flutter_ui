import 'package:stratum_ui/src/src.dart';

abstract class AppStatefulWidget extends StatefulWidget {
  const AppStatefulWidget({
    super.key,
    this.debug = false,
    this.size,
    this.state = FullWidgetState.normal,
    this.feedbackState,
    this.themeMode,
    this.breakpoint,
    this.padding,
    this.margin,
    this.border,
    this.borderRadius,
    this.disabled,
    this.loading,
  });

  final bool debug;
  final WidgetSize? size;
  final FullWidgetState state;
  final FeedbackState? feedbackState;
  final ThemeMode? themeMode;
  final Breakpoint? breakpoint;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final Border? border;
  final BorderRadius? borderRadius;
  final bool? disabled;
  final bool? loading;

}
