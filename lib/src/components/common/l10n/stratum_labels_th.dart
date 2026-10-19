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
  String reorderMoveAnnouncement(int position, int count) {
    return 'ย้ายไปลำดับที่ $position จาก $count';
  }

  @override
  String get reorderAtStartAnnouncement => 'อยู่ต้นรายการแล้ว';

  @override
  String get reorderAtEndAnnouncement => 'อยู่ท้ายรายการแล้ว';

  @override
  String get drawerLabel => 'เมนูการนำทาง';

  @override
  String get dismissLabel => 'ปิด';

  @override
  String get dialogLabel => 'กล่องโต้ตอบ';

  @override
  String get sheetLabel => 'ชีต';

  @override
  String get dividerLabel => 'ปรับขนาดแผง';

  @override
  String get noticePositiveLabel => 'สำเร็จ';

  @override
  String get noticeInfoLabel => 'ข้อมูล';

  @override
  String get noticeWarningLabel => 'คำเตือน';

  @override
  String get noticeNegativeLabel => 'ข้อผิดพลาด';

  @override
  String noticeShortcutHint(String key) {
    return 'กด $key เพื่อไปที่การแจ้งเตือนนี้';
  }
}
