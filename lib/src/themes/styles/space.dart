import 'package:stratum_ui/src/src.dart';

class AppSpace {
  const AppSpace({
    this.mobilePadding = 20,
    this.gapMobilePadding = const Gap(20),
    this.insetMobileAll = const EdgeInsets.all(20),
    this.insetMobileLeft = const EdgeInsets.only(left: 20),
    this.insetMobileRight = const EdgeInsets.only(right: 20),
    this.insetMobileTop = const EdgeInsets.only(top: 20),
    this.insetMobileBottom = const EdgeInsets.only(bottom: 20),
    this.insetMobileHorizontal = const EdgeInsets.symmetric(horizontal: 20),
    this.insetMobileVertical = const EdgeInsets.symmetric(vertical: 20),
    this.desktopPadding = 32,
    this.gapDesktopPadding = const Gap(32),
    this.insetDesktopAll = const EdgeInsets.all(32),
    this.insetDesktopLeft = const EdgeInsets.only(left: 32),
    this.insetDesktopRight = const EdgeInsets.only(right: 32),
    this.insetDesktopTop = const EdgeInsets.only(top: 32),
    this.insetDesktopBottom = const EdgeInsets.only(bottom: 32),
    this.insetDesktopHorizontal = const EdgeInsets.symmetric(horizontal: 32),
    this.insetDesktopVertical = const EdgeInsets.symmetric(vertical: 32),
    this.xxxs = 8,
    this.gapXxxs = const Gap(8),
    this.insetXxxsAll = const EdgeInsets.all(8),
    this.insetXxxsLeft = const EdgeInsets.only(left: 8),
    this.insetXxxsRight = const EdgeInsets.only(right: 8),
    this.insetXxxsTop = const EdgeInsets.only(top: 8),
    this.insetXxxsBottom = const EdgeInsets.only(bottom: 8),
    this.insetXxxsHorizontal = const EdgeInsets.symmetric(horizontal: 8),
    this.insetXxxsVertical = const EdgeInsets.symmetric(vertical: 8),
    this.xxs = 12,
    this.gapXxs = const Gap(12),
    this.insetXxsAll = const EdgeInsets.all(12),
    this.insetXxsLeft = const EdgeInsets.only(left: 12),
    this.insetXxsRight = const EdgeInsets.only(right: 12),
    this.insetXxsTop = const EdgeInsets.only(top: 12),
    this.insetXxsBottom = const EdgeInsets.only(bottom: 12),
    this.insetXxsHorizontal = const EdgeInsets.symmetric(horizontal: 12),
    this.insetXxsVertical = const EdgeInsets.symmetric(vertical: 12),
    this.xs = 16,
    this.gapXs = const Gap(16),
    this.insetXsAll = const EdgeInsets.all(16),
    this.insetXsLeft = const EdgeInsets.only(left: 16),
    this.insetXsRight = const EdgeInsets.only(right: 16),
    this.insetXsTop = const EdgeInsets.only(top: 16),
    this.insetXsBottom = const EdgeInsets.only(bottom: 16),
    this.insetXsHorizontal = const EdgeInsets.symmetric(horizontal: 16),
    this.insetXsVertical = const EdgeInsets.symmetric(vertical: 16),
    this.sm = 20,
    this.gapSm = const Gap(20),
    this.insetSmAll = const EdgeInsets.all(20),
    this.insetSmLeft = const EdgeInsets.only(left: 20),
    this.insetSmRight = const EdgeInsets.only(right: 20),
    this.insetSmTop = const EdgeInsets.only(top: 20),
    this.insetSmBottom = const EdgeInsets.only(bottom: 20),
    this.insetSmHorizontal = const EdgeInsets.symmetric(horizontal: 20),
    this.insetSmVertical = const EdgeInsets.symmetric(vertical: 20),
    this.md = 24,
    this.gapMd = const Gap(24),
    this.insetMdAll = const EdgeInsets.all(24),
    this.insetMdLeft = const EdgeInsets.only(left: 24),
    this.insetMdRight = const EdgeInsets.only(right: 24),
    this.insetMdTop = const EdgeInsets.only(top: 24),
    this.insetMdBottom = const EdgeInsets.only(bottom: 24),
    this.insetMdHorizontal = const EdgeInsets.symmetric(horizontal: 24),
    this.insetMdVertical = const EdgeInsets.symmetric(vertical: 24),
    this.lg = 28,
    this.gapLg = const Gap(28),
    this.insetLgAll = const EdgeInsets.all(28),
    this.insetLgLeft = const EdgeInsets.only(left: 28),
    this.insetLgRight = const EdgeInsets.only(right: 28),
    this.insetLgTop = const EdgeInsets.only(top: 28),
    this.insetLgBottom = const EdgeInsets.only(bottom: 28),
    this.insetLgHorizontal = const EdgeInsets.symmetric(horizontal: 28),
    this.insetLgVertical = const EdgeInsets.symmetric(vertical: 28),
    this.xl = 32,
    this.gapXl = const Gap(32),
    this.insetXlAll = const EdgeInsets.all(32),
    this.insetXlLeft = const EdgeInsets.only(left: 32),
    this.insetXlRight = const EdgeInsets.only(right: 32),
    this.insetXlTop = const EdgeInsets.only(top: 32),
    this.insetXlBottom = const EdgeInsets.only(bottom: 32),
    this.insetXlHorizontal = const EdgeInsets.symmetric(horizontal: 32),
    this.insetXlVertical = const EdgeInsets.symmetric(vertical: 32),
    this.xxl = 36,
    this.gapXxl = const Gap(36),
    this.insetXxlAll = const EdgeInsets.all(36),
    this.insetXxlLeft = const EdgeInsets.only(left: 36),
    this.insetXxlRight = const EdgeInsets.only(right: 36),
    this.insetXxlTop = const EdgeInsets.only(top: 36),
    this.insetXxlBottom = const EdgeInsets.only(bottom: 36),
    this.insetXxlHorizontal = const EdgeInsets.symmetric(horizontal: 36),
    this.insetXxlVertical = const EdgeInsets.symmetric(vertical: 36),
    this.xxxl = 40,
    this.gapXxxl = const Gap(40),
    this.insetXxxlAll = const EdgeInsets.all(40),
    this.insetXxxlLeft = const EdgeInsets.only(left: 40),
    this.insetXxxlRight = const EdgeInsets.only(right: 40),
    this.insetXxxlTop = const EdgeInsets.only(top: 40),
    this.insetXxxlBottom = const EdgeInsets.only(bottom: 40),
    this.insetXxxlHorizontal = const EdgeInsets.symmetric(horizontal: 40),
    this.insetXxxlVertical = const EdgeInsets.symmetric(vertical: 40),
  });

  final double mobilePadding;
  final Gap gapMobilePadding;
  final EdgeInsets insetMobileAll;
  final EdgeInsets insetMobileLeft;
  final EdgeInsets insetMobileRight;
  final EdgeInsets insetMobileTop;
  final EdgeInsets insetMobileBottom;
  final EdgeInsets insetMobileHorizontal;
  final EdgeInsets insetMobileVertical;
  final double desktopPadding;
  final Gap gapDesktopPadding;
  final EdgeInsets insetDesktopAll;
  final EdgeInsets insetDesktopLeft;
  final EdgeInsets insetDesktopRight;
  final EdgeInsets insetDesktopTop;
  final EdgeInsets insetDesktopBottom;
  final EdgeInsets insetDesktopHorizontal;
  final EdgeInsets insetDesktopVertical;
  final double xxxs;
  final Gap gapXxxs;
  final EdgeInsets insetXxxsAll;
  final EdgeInsets insetXxxsLeft;
  final EdgeInsets insetXxxsRight;
  final EdgeInsets insetXxxsTop;
  final EdgeInsets insetXxxsBottom;
  final EdgeInsets insetXxxsHorizontal;
  final EdgeInsets insetXxxsVertical;
  final double xxs;
  final Gap gapXxs;
  final EdgeInsets insetXxsAll;
  final EdgeInsets insetXxsLeft;
  final EdgeInsets insetXxsRight;
  final EdgeInsets insetXxsTop;
  final EdgeInsets insetXxsBottom;
  final EdgeInsets insetXxsHorizontal;
  final EdgeInsets insetXxsVertical;
  final double xs;
  final Gap gapXs;
  final EdgeInsets insetXsAll;
  final EdgeInsets insetXsLeft;
  final EdgeInsets insetXsRight;
  final EdgeInsets insetXsTop;
  final EdgeInsets insetXsBottom;
  final EdgeInsets insetXsHorizontal;
  final EdgeInsets insetXsVertical;
  final double sm;
  final Gap gapSm;
  final EdgeInsets insetSmAll;
  final EdgeInsets insetSmLeft;
  final EdgeInsets insetSmRight;
  final EdgeInsets insetSmTop;
  final EdgeInsets insetSmBottom;
  final EdgeInsets insetSmHorizontal;
  final EdgeInsets insetSmVertical;
  final double md;
  final Gap gapMd;
  final EdgeInsets insetMdAll;
  final EdgeInsets insetMdLeft;
  final EdgeInsets insetMdRight;
  final EdgeInsets insetMdTop;
  final EdgeInsets insetMdBottom;
  final EdgeInsets insetMdHorizontal;
  final EdgeInsets insetMdVertical;
  final double lg;
  final Gap gapLg;
  final EdgeInsets insetLgAll;
  final EdgeInsets insetLgLeft;
  final EdgeInsets insetLgRight;
  final EdgeInsets insetLgTop;
  final EdgeInsets insetLgBottom;
  final EdgeInsets insetLgHorizontal;
  final EdgeInsets insetLgVertical;
  final double xl;
  final Gap gapXl;
  final EdgeInsets insetXlAll;
  final EdgeInsets insetXlLeft;
  final EdgeInsets insetXlRight;
  final EdgeInsets insetXlTop;
  final EdgeInsets insetXlBottom;
  final EdgeInsets insetXlHorizontal;
  final EdgeInsets insetXlVertical;
  final double xxl;
  final Gap gapXxl;
  final EdgeInsets insetXxlAll;
  final EdgeInsets insetXxlLeft;
  final EdgeInsets insetXxlRight;
  final EdgeInsets insetXxlTop;
  final EdgeInsets insetXxlBottom;
  final EdgeInsets insetXxlHorizontal;
  final EdgeInsets insetXxlVertical;
  final double xxxl;
  final Gap gapXxxl;
  final EdgeInsets insetXxxlAll;
  final EdgeInsets insetXxxlLeft;
  final EdgeInsets insetXxxlRight;
  final EdgeInsets insetXxxlTop;
  final EdgeInsets insetXxxlBottom;
  final EdgeInsets insetXxxlHorizontal;
  final EdgeInsets insetXxxlVertical;
}
