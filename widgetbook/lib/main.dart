import 'package:stratum_ui/stratum_ui.dart';
import 'package:widgetbook/widgetbook.dart' hide ThemeMode;

import 'components.g.dart';
import 'shell/catalog_config.dart';
import 'shell/catalog_themes.dart';

/// Runs the FO-11 component catalog under the shared toolbar; pages arrive as
/// `*.stories.dart` files in later tasks.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final themes = await loadCatalogThemes();
  runWidgetbook(catalogConfig(components: components, themes: themes));
}
