enum WidgetSize {
  xxs,
  xs,
  sm,
  md,
  lg,
  xl,
  xxl;

  bool get isXxs => this == WidgetSize.xxs; //
  bool get isXs => this == WidgetSize.xs; //
  bool get isSm => this == WidgetSize.sm; //
  bool get isMd => this == WidgetSize.md; //
  bool get isLg => this == WidgetSize.lg; //
  bool get isXl => this == WidgetSize.xl; //
  bool get isXxl => this == WidgetSize.xxl; //

  bool get isSmall =>
      this == WidgetSize.sm ||
      this == WidgetSize.xs ||
      this == WidgetSize.xxs; //
  bool get isMedium => this == WidgetSize.md; //
  bool get isLarge =>
      this == WidgetSize.sm ||
      this == WidgetSize.lg ||
      this == WidgetSize.xl ||
      this == WidgetSize.xxl; //
}

enum FontSize { s10, s12, s14, s16, s18, s20, s24, s36, s48, s56, custom }

enum FontType { header, paragraph, number, numberMono, code, ui, table }

enum FocusType {
  focused,
  focusedVisible,
  none,
  invisible;

  bool get isAnyFocused => isFocused || isFocusedVisible; //
  bool get isFocused => this == focused; //
  bool get isFocusedVisible => this == focusedVisible; //
  bool get isNone => this == none; //
  bool get isInvisible => this == invisible; //

  bool get isNotFocused => !isFocused; //
  bool get isNotFocusedVisible => !isFocusedVisible; //
  bool get isNotNone => !isNone; //
  bool get isNotInvisible => !isInvisible; //
}

enum InputMethod {
  none,
  keyboard,
  pointer;  //touch, mouse, stylus, trackpad

  bool get isNone => this == none; //
  bool get isKeyboard => this == keyboard; //
  bool get isPointer => this == pointer; //

  bool get isNotNone => !isNone; //
  bool get isNotKeyboard => !isKeyboard; //
  bool get isNotPointer => !isPointer; //
}

enum FontColor {
  brandPrimary,
  brandSecondary,
  brandTertiary,
  primary,
  primaryInverse,
  primaryOnColor,
  secondary,
  secondaryInverse,
  tertiary,
  tertiaryInverse,
}
