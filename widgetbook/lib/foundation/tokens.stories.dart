import 'package:stratum_ui/stratum_ui.dart';
import 'package:widgetbook/widgetbook.dart' hide ThemeMode;

import '../shell/catalog_section.dart';
import 'tokens_page.dart';

part 'tokens.stories.g.dart';

const meta = Meta(TokensPage.new);

final componentMeta = ComponentMeta(
  name: 'Tokens',
  path: CatalogSection.foundation.label,
);

/// The one story of the page: every token group of the active theme. A
/// Foundation page is no component page, so it carries no story set.
final $Tokens = _Story();
