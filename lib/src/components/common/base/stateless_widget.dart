import 'package:stratum_ui/src/src.dart';

abstract class AppStatelessWidget extends StatelessWidget {
  const AppStatelessWidget({
    super.key,
    this.size,
    this.themeMode,
    this.breakpoint,
    this.opacity,
    this.debug = false,
    this.state = FullWidgetState.normal,
    this.feedbackState,
    this.disabled = false,
    this.loading = false,
    this.padding,
    this.margin,
    this.color,
    this.customColor,
    this.border,
    this.borderRadius,
  });

  final WidgetSize? size;
  final Breakpoint? breakpoint;
  final Border? border;
  final BorderRadius? borderRadius;

  final FullWidgetState state;
  final FeedbackState? feedbackState;
  final bool debug;
  final double? opacity;
  final ThemeMode? themeMode;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final ColorEnum? color;
  final Color? customColor;
  final bool disabled;
  final bool loading;

  Locale get currentLocale => LocaleSettings.currentLocale.flutterLocale;

  WidgetSize resolveSize(BuildContext context) =>
      size ?? resolveTheme(context).defaultWidgetSize;

  AppThemeData resolveTheme(BuildContext context) =>
      ThemeApplication.of(context, themeMode: themeMode);

  Breakpoint resolveBreakpoint(BuildContext context) =>
      breakpoint ?? context.breakpoint;

  BorderRadius resolveBorderRadius(BuildContext context) =>
      borderRadius ?? resolveTheme(context).borderRadius.md;

  Widget buildResponsive(
    BuildContext context, {
    required ResponsiveBuilder child,
  }) {
    final breakpoint = ResponsiveBreakpoints.of(context).breakpoint;
    return child(PlatformChecker.platform, breakpoint);
  }

  Widget buildTapClearFocus(BuildContext context, {required Widget child}) {
    return GestureDetector(
      onTap: () {
        context.clearFocus();
      },
      child: child,
    );
  }

  Widget buildTapRequestScopeFocus(
    BuildContext context, {
    required Widget child,
  }) {
    return GestureDetector(
      onTap: () {
        context.requestScopeFocus();
      },
      child: child,
    );
  }
}
