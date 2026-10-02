/// The named text sizes of the theme's typography.
enum FontSize {
  s10(10),
  s12(12),
  s14(14),
  s16(16),
  s18(18),
  s20(20),
  s24(24),
  s36(36),
  s48(48),
  s56(56);

  new(this.value);

  /// The size in logical pixels.
  final double value;
}
