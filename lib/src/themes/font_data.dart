import 'package:stratum_ui/src/src.dart';

class StratumFontData {
  const new({
    required this.fontFamily,
    this.fontSizeScaleAdjustment = 1.0,
    this.letterSpaceScaleAdjustment = 1.0,
    this.package,
  });

  final String fontFamily;
  final double fontSizeScaleAdjustment;
  final double letterSpaceScaleAdjustment;
  final String? package;
}

// class StratumFontFamily {
//   const new({
//     required this.header,
//     required this.headerMono,
//     required this.number,
//     required this.numberMono,
//     required this.paragraph,
//     required this.paragraphMono,
//     required this.code,
//     required this.body,
//     required this.bodyMono,
//   });
// }
//
// class StratumHeaderFamily {
//   const new({
//     required this.s56,
//     required this.s48,
//     required this.s36,
//     required this.s24,
//     required this.s20,
//     required this.s18,
//     required this.s16,
//     required this.s14,
//     required this.s12,
//     required this.s10,
//   });
// }
//
// class StratumNumberFamily {
//   const new({
//     required this.s56,
//     required this.s48,
//     required this.s36,
//     required this.s24,
//     required this.s20,
//     required this.s18,
//     required this.s16,
//     required this.s14,
//     required this.s12,
//   });
// }
//
// class StratumParagraphFamily {
//   const new({
//     required this.s20,
//     required this.s18,
//     required this.s16,
//     required this.s14,
//     required this.s12,
//   });
// }
//
// class StratumCodeFamily {
//   const new({
//     required this.s20,
//     required this.s18,
//     required this.s16,
//     required this.s14,
//     required this.s12,
//   });
// }
//
// class StratumBodyFamily {
//   const new({
//     required this.s18,
//     required this.s16,
//     required this.s14,
//     required this.s12,
//     required this.s10,
//   });
// }
//
