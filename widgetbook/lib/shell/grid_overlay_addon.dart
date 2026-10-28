import 'package:stratum_ui/stratum_ui.dart';
import 'package:widgetbook/widgetbook.dart' hide ThemeMode;

/// The toolbar's grid setting: when on, a layout grid paints over the story
/// and lets taps through (fo11/us02/fr03).
///
/// Replaces Widgetbook's `GridAddon`, which is always on and paints the grid
/// under the story. The paper's color, interval, and subdivisions copy it.
class GridOverlayAddon extends Addon<bool> with SingleFieldOnly {
  GridOverlayAddon() : super(name: 'Grid', initialValue: false);

  @override
  Field<bool> get field =>
      BooleanField(name: 'enabled', initialValue: initialValue);

  @override
  Widget apply(BuildContext context, Widget child, bool setting) {
    if (!setting) return child;
    return StackLayout(
      fit: StackFit.passthrough,
      children: [
        child,
        // A childless GridPaper sizes to zero under a loose Stack child
        // constraint; Positioned.fill stretches it over the story.
        Positioned.fill(
          child: IgnorePointer(
            child: GridPaper(
              color: Colors.grey.withAlpha(255 ~/ 2),
              interval: 50,
              subdivisions: 2,
            ),
          ),
        ),
      ],
    );
  }
}
