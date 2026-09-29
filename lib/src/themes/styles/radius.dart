import 'package:stratum_ui/src/src.dart';

class AppRadius {
  const AppRadius({
    this.zero = BorderRadius.zero,
    this.xs = const BorderRadius.all(Radius.circular(4.0)),
    this.sm = const BorderRadius.all(Radius.circular(6.0)),
    this.md = const BorderRadius.all(Radius.circular(8.0)),
    this.lg = const BorderRadius.all(Radius.circular(10.0)),
    this.xl = const BorderRadius.all(Radius.circular(12.0)),
    this.cardSm = const BorderRadius.all(Radius.circular(16.0)),
    this.cardMd = const BorderRadius.all(Radius.circular(20.0)),
    this.cardLg = const BorderRadius.all(Radius.circular(24.0)),
    this.full = const BorderRadius.all(Radius.circular(1000.0)),
    this.defaultIos = const BorderRadius.all(Radius.circular(38.0)),
  });

  final BorderRadius zero;
  final BorderRadius xs;
  final BorderRadius sm;
  final BorderRadius md;
  final BorderRadius lg;
  final BorderRadius xl;
  final BorderRadius cardSm;
  final BorderRadius cardMd;
  final BorderRadius cardLg;
  final BorderRadius full;
  final BorderRadius defaultIos;
}
