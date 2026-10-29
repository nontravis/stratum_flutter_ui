import 'package:stratum_ui/stratum_ui.dart';
import 'package:widgetbook/widgetbook.dart' hide ThemeMode;

/// Gives the story its own navigator, innermost and off the toolbar, so a
/// route or overlay entry it opens builds under every toolbar setting
/// (fo11/us02/fr01).
///
/// - A route pushed with `rootNavigator: true` still lands on Widgetbook's
///   own app navigator, the outermost one above every story.
/// - It has no field, so Widgetbook leaves it off the toolbar.
class StageAddon extends BuilderAddon {
  StageAddon() : super(name: 'Stage', builder: _stage);

  // `pages` rather than `onGenerateRoute`, so the page tracks the story on
  // every rebuild instead of capturing its first build.
  static Widget _stage(BuildContext context, Widget child) => Navigator(
    onDidRemovePage: (_) {},
    pages: [MaterialPage<void>(child: child)],
  );
}
