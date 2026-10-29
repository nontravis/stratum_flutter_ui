import 'package:stratum_ui/stratum_ui.dart';
import 'package:stratum_ui_widgetbook/kit/docs/catalog_text.dart';
import 'package:stratum_ui_widgetbook/kit/docs/toolbar_locale.dart';
import 'package:url_launcher/link.dart';
import 'package:widgetbook/widgetbook.dart' hide ThemeMode;

/// Links the component's Figma page, or says it has none (fo11/us03/fr01).
class FigmaLinkDocBlock extends DocBlock {
  const FigmaLinkDocBlock(this.figma, {super.key});

  /// The Figma page, or null when the component has no Figma node.
  final Uri? figma;

  @override
  Widget build(BuildContext context) {
    final locale = toolbarLocale(context);
    final uri = figma;
    if (uri == null) return Text(CatalogText.noFigmaDesign.resolve(locale));
    return Link(
      uri: uri,
      target: LinkTarget.blank,
      builder: (context, followLink) => TextButton(
        onPressed: followLink,
        child: Text(CatalogText.openInFigma.resolve(locale)),
      ),
    );
  }
}
