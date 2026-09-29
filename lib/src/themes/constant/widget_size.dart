/// The size of a widget, ordered from smallest to largest.
///
/// Compare sizes with the operators, e.g. `size <= WidgetSize.small`.
enum WidgetSize {
  tiny,
  extraSmall,
  small,
  medium,
  large,
  extraLarge,
  huge;

  bool get isTiny => this == tiny;
  bool get isExtraSmall => this == extraSmall;
  bool get isSmall => this == small;
  bool get isMedium => this == medium;
  bool get isLarge => this == large;
  bool get isExtraLarge => this == extraLarge;
  bool get isHuge => this == huge;

  bool operator <(WidgetSize other) => index < other.index;

  bool operator <=(WidgetSize other) => index <= other.index;

  bool operator >(WidgetSize other) => index > other.index;

  bool operator >=(WidgetSize other) => index >= other.index;
}
