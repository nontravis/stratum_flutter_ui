import 'package:stratum_ui/stratum_ui.dart';
import 'package:stratum_ui_widgetbook/kit/docs/catalog_docs.dart';
import 'package:stratum_ui_widgetbook/kit/docs/catalog_text.dart';
import 'package:stratum_ui_widgetbook/kit/docs/toolbar_locale.dart';
import 'package:widgetbook/widgetbook.dart' hide ThemeMode;

/// Shows the copyable usage code with its Do and Don't lists
/// (fo11/us03/fr01).
class UsageDocBlock extends DocBlock {
  const UsageDocBlock(this.docs, {super.key});

  final CatalogDocs docs;

  @override
  Widget build(BuildContext context) {
    final locale = toolbarLocale(context);
    return ColumnLayout(
      crossAxisAlignment: CrossAxisAlignment.start,
      gap: 8,
      children: [
        SelectableText(
          docs.usage,
          style: const TextStyle(fontFamily: 'monospace'),
        ),
        TextButton(
          onPressed: () => Clipboard.setData(ClipboardData(text: docs.usage)),
          child: Text(CatalogText.copy.resolve(locale)),
        ),
        if (docs.dos.isNotEmpty)
          _NoteList(CatalogText.doLabel.resolve(locale), docs.dos),
        if (docs.donts.isNotEmpty)
          _NoteList(CatalogText.dontLabel.resolve(locale), docs.donts),
      ],
    );
  }
}

class _NoteList extends StatelessWidget {
  const _NoteList(this.label, this.lines);

  final String label;
  final List<String> lines;

  @override
  Widget build(BuildContext context) => ColumnLayout(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: Theme.of(context).textTheme.titleMedium),
      for (final line in lines) Text(line),
    ],
  );
}
