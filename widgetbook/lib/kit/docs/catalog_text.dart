import 'package:stratum_ui_widgetbook/kit/sample_text.dart';

/// The built-in text of the docs node, in both toolbar languages.
///
/// Resolve each with `toolbarLocale`.
abstract final class CatalogText {
  static const openInFigma = SampleText(
    th: 'เปิดใน Figma',
    en: 'Open in Figma',
  );
  static const noFigmaDesign = SampleText(
    th: 'ไม่มีแบบใน Figma',
    en: 'No Figma design',
  );
  static const copy = SampleText(th: 'คัดลอก', en: 'Copy');
  static const doLabel = SampleText(th: 'ควรทำ', en: 'Do');
  static const dontLabel = SampleText(th: 'ไม่ควรทำ', en: "Don't");
  static const accessibility = SampleText(
    th: 'การเข้าถึง',
    en: 'Accessibility',
  );
}
