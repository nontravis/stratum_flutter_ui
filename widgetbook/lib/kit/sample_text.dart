import 'package:flutter/widgets.dart';

/// A text a story shows in a component, in both toolbar languages
/// (fo11/us04/fr05).
final class SampleText {
  const SampleText({required this.th, required this.en});

  final String th;
  final String en;

  /// Returns [th] under a Thai [locale], [en] under any other.
  String resolve(Locale locale) => locale.languageCode == 'th' ? th : en;

  /// Returns the text for the locale [context] sees, which is the toolbar's
  /// language inside a story.
  String of(BuildContext context) => resolve(Localizations.localeOf(context));
}

/// The sample texts every story draws from.
///
/// Read each with `of(context)` so the
/// toolbar language switches them all (s03 INV-11).
abstract final class SampleTexts {
  static const label = SampleText(th: 'ป้ายกำกับ', en: 'Label');
  static const title = SampleText(th: 'หัวข้อ', en: 'Title');
  static const message = SampleText(
    th: 'ข้อความตัวอย่างสำหรับดูการตัดบรรทัดของภาษาไทยในพื้นที่แคบ',
    en: 'A sample message to see how text wraps in a narrow space',
  );
  static const close = SampleText(th: 'ปิด', en: 'Close');
}
