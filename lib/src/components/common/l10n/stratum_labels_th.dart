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
  String get placeholderPageTitle => 'เร็วๆ นี้';

  @override
  String get forceUpdateTitle => 'ต้องอัปเดตแอป';

  @override
  String get forceUpdateMessage =>
      'กรุณาอัปเดตแอปเป็นเวอร์ชันล่าสุดเพื่อใช้งานต่อ';

  @override
  String get maintenanceTitle => 'ปิดปรับปรุงชั่วคราว';

  @override
  String get maintenanceMessage => 'ระบบกำลังปรับปรุง กรุณาลองใหม่ภายหลัง';

  @override
  String get softUpdateTitle => 'มีเวอร์ชันใหม่';

  @override
  String get softUpdateMessage => 'มีเวอร์ชันใหม่พร้อมให้อัปเดตแล้ว';

  @override
  String get updateLabel => 'อัปเดต';

  @override
  String get laterLabel => 'ไว้ทีหลัง';
}
