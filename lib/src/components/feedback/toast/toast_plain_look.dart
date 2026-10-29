import 'package:stratum_ui/src/components/common/model/solid_fill.dart';
import 'package:stratum_ui/src/src.dart';

/// The close time of a notice: 4 s with no action, 8 s with one, and none
/// while a screen reader runs for a notice with an action (US-01 FR-04
/// E01, E02).
Duration? toastCloseTime({
  required bool hasAction,
  required bool screenReader,
}) {
  if (hasAction && screenReader) return null;
  return Duration(seconds: hasAction ? 8 : 4);
}

/// The plain look of one notice: the kind's icon, the wrapping message, the
/// action, and the close button, every visual value from theme tokens
/// (US-01 FR-06; s03 INV-12).
///
/// The host builds it unless an app `builder` replaces it; an app also draws
/// it on its own, outside any host, or inside its own look. Drawn alone it
/// starts no timer and makes no announcement: the close button, running the
/// notice's `close`, is the one way to remove it (FR-06 E07, E08; s03
/// INV-21).
class StratumToastPlainLook extends StatelessWidget {
  const new({super.key, required this.notice, this.corners});

  final StratumToastNotice notice;

  /// The surface's corners at the theme-token layer, null keeping
  /// `radius.lg` on all four; the host passes a float notice's, curved
  /// next to a screen corner (s03 INV-6).
  final BorderRadius? corners;

  @override
  Widget build(BuildContext context) {
    final style = _style(context);
    final surface = _surface(context, style);
    // A solid notice's surface declares the one solid color it paints,
    // opacity folded, on both edges (s03 INV-17; US-01 FR-02 E08).
    // The host sizes and places every look, so a float one is the surface
    // alone (s03 INV-13).
    return notice.placement is StratumToastSolid
        ? SystemBarFill(color: solidFillColor(style), child: surface)
        : surface;
  }

  /// The notice's surface style, each later source winning: theme tokens,
  /// the app-wide notice defaults, the page's `snack` layer, then the
  /// call's `customStyle` (s03 INV-16).
  WidgetStyle _style(BuildContext context) {
    final theme = context.theme;
    return WidgetStyle(
          backgroundColor: theme.color.background.defaults.normal,
          border: Border.all(color: _kindBorder(theme, notice.kind)),
          borderRadius: corners ?? BorderRadius.circular(theme.radius.lg),
          dropShadow: theme.shadow.level4,
          padding: EdgeInsets.all(theme.space.md),
        )
        .merge(
          StratumComponentDefaults.partsOf<WidgetStyle>(
            context,
            StratumToastHost,
          ),
        )
        .merge(notice.pageSnack)
        .merge(notice.customStyle);
  }

  /// The kind's border color, `info` reading brand (s03 INV-12).
  static Color _kindBorder(StratumTheme theme, FeedbackState kind) =>
      switch (kind) {
        FeedbackState.positive => theme.color.border.color.positive,
        FeedbackState.negative => theme.color.border.color.negative,
        FeedbackState.warning => theme.color.border.color.warning,
        FeedbackState.info => theme.color.border.color.brand,
      };

  /// The kind's icon color, `info` reading brand (s03 INV-12).
  static Color _kindIcon(StratumTheme theme, FeedbackState kind) =>
      switch (kind) {
        FeedbackState.positive => theme.color.icon.color.positive,
        FeedbackState.negative => theme.color.icon.color.negative,
        FeedbackState.warning => theme.color.icon.color.warning,
        FeedbackState.info => theme.color.icon.color.brand,
      };

  /// The kind's icon: every kind differs by icon as well as color
  /// (NFR-U08; s03 INV-12).
  static IconData _iconOf(FeedbackState kind) => switch (kind) {
    FeedbackState.positive => Icons.check_circle_outline,
    FeedbackState.info => Icons.info_outline,
    FeedbackState.warning => Icons.warning_amber_outlined,
    FeedbackState.negative => Icons.error_outline,
  };

  /// The notice's content: the kind icon, the wrapping message, the action,
  /// and the close button, the message and icon on the theme's body
  /// typography and primary text and icon colors (s03 INV-12).
  Widget _surface(BuildContext context, WidgetStyle style) {
    final theme = context.theme;
    final action = notice.action;
    return ContainerLayout(
      style: style.copyWith(width: double.infinity),
      child: Padding(
        padding: notice.insets,
        child: DefaultTextStyle(
          style: StratumTextStyle.body.s14.build(context),
          child: IconTheme.merge(
            data: IconThemeData(
              color: theme.color.icon.defaults.primary,
              size: theme.space.xl,
            ),
            child: RowLayout(
              children: [
                // `container: true` gives the icon its own semantics node;
                // a bare `Icon.semanticLabel` has no boundary of its own
                // and merges into the row's nearest one, combining with
                // the message text instead of staying its own node.
                Semantics(
                  container: true,
                  label: notice.kindLabel,
                  child: ExcludeSemantics(
                    child: Icon(
                      _iconOf(notice.kind),
                      color: _kindIcon(theme, notice.kind),
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    notice.message,
                    softWrap: true,
                    style: TextStyle(color: theme.color.text.defaults.primary),
                  ),
                ),
                if (action != null)
                  StratumInkWell(
                    onTap: () {
                      action.onPressed();
                      notice.close();
                    },
                    child: Text(
                      action.label,
                      style: TextStyle(color: theme.color.text.color.brand),
                    ),
                  ),
                StratumInkWell(
                  onTap: notice.close,
                  semantics: SemanticsProperties(label: notice.closeLabel),
                  child: const Icon(Icons.close),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
