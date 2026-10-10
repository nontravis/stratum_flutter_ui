import 'package:stratum_ui/src/components/common/l10n/built_in_labels.dart';
import 'package:stratum_ui/src/src.dart';

/// A page to place where a screen is not built yet (CO-05-08): a title,
/// and an icon and a message only when passed, centered in the space its
/// parent gives it, with no app bar and no back action of its own.
///
/// The title defaults to the built-in placeholder page title, in Thai for
/// a Thai locale and in English otherwise. The text wraps, and the page
/// scrolls when it is taller than its space.
class StratumPlaceholderPage extends StatelessWidget {
  const new({super.key, this.title, this.message, this.icon});

  /// Replaces the built-in placeholder page title, on screen and for a
  /// screen reader.
  final String? title;

  /// Shown below the title only when passed; it has no built-in text.
  final String? message;

  /// Shown above the title only when passed, at [iconSize] in the theme's
  /// secondary icon color, and skipped by a screen reader.
  final Widget? icon;

  /// The size the page gives [icon], whatever the text scale.
  static const double iconSize = 48;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final icon = this.icon;
    final message = this.message;
    return ColumnLayout(
      style: const WidgetStyle(width: double.infinity, height: double.infinity),
      scroll: const StratumScroll(fillViewport: true),
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (icon != null) ...[
          ExcludeSemantics(
            child: IconTheme.merge(
              data: IconThemeData(
                size: iconSize,
                color: theme.color.icon.defaults.secondary,
              ),
              child: icon,
            ),
          ),
          Space.gap(theme.space.md),
        ],
        Semantics(
          container: true,
          header: true,
          child: Text(
            title ?? builtInLabelsOf(context).placeholderPageTitle,
            textAlign: TextAlign.center,
            style: StratumTextStyle.header.s20.colorPrimary.build(context),
          ),
        ),
        if (message != null) ...[
          Space.gap(theme.space.sm),
          Text(
            message,
            textAlign: TextAlign.center,
            style: StratumTextStyle.body.s16.colorPrimary.build(context),
          ),
        ],
      ],
    );
  }
}
