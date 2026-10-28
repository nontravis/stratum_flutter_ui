import 'package:stratum_ui/stratum_ui.dart';
import 'package:stratum_ui_widgetbook/kit/docs/catalog_text.dart';
import 'package:stratum_ui_widgetbook/kit/docs/toolbar_locale.dart';
import 'package:widgetbook/widgetbook.dart' hide ThemeMode;

/// Lists the component's accessibility notes under a heading
/// (fo11/us03/fr01).
class AccessibilityNotesDocBlock extends DocBlock {
  const AccessibilityNotesDocBlock(this.notes, {super.key});

  /// One line per note.
  final List<String> notes;

  @override
  Widget build(BuildContext context) => ColumnLayout(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        CatalogText.accessibility.resolve(toolbarLocale(context)),
        style: Theme.of(context).textTheme.titleMedium,
      ),
      for (final note in notes) Text(note),
    ],
  );
}
