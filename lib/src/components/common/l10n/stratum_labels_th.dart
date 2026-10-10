// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'stratum_labels.dart';

// ignore_for_file: type=lint

/// The translations for Thai (`th`).
class StratumLabelsTh extends StratumLabels {
  StratumLabelsTh([String locale = 'th']) : super(locale);

  @override
  String get closeButtonLabel => 'ปิด';

  @override
  String get expanded => 'ขยายแล้ว';

  @override
  String get collapsed => 'ยุบแล้ว';

  @override
  String get removeTagLabel => 'ลบ';

  @override
  String get loadingLabel => 'กำลังโหลด';

  @override
  String get requiredMarker => 'จำเป็น';

  @override
  String get showMenuLabel => 'แสดงเมนู';

  @override
  String get retryLabel => 'ลองอีกครั้ง';

  @override
  String get failureMessage => 'เกิดข้อผิดพลาด';

  @override
  String get placeholderPageTitle => 'เร็วๆ นี้';
}
