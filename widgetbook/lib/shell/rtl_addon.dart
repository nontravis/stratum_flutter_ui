import 'package:stratum_ui/stratum_ui.dart';
import 'package:widgetbook/widgetbook.dart' hide ThemeMode;

/// The toolbar's right-to-left setting, apart from the language: when on, the
/// story lays out right to left in whichever locale is set (fo11/us02/fr02).
class RtlAddon extends Addon<bool> with SingleFieldOnly {
  RtlAddon() : super(name: 'Right to left', initialValue: false);

  @override
  Field<bool> get field =>
      BooleanField(name: 'enabled', initialValue: initialValue);

  @override
  Widget apply(BuildContext context, Widget child, bool setting) {
    if (!setting) return child;
    return Directionality(textDirection: TextDirection.rtl, child: child);
  }
}
