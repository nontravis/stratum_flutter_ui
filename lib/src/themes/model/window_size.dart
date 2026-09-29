enum WindowSize {
  compact(0),
  medium(600),
  expanded(840),
  large(1200),
  extraLarge(1600);

  const new(this.minWidth);

  final double minWidth;

  static WindowSize fromWidth(double width) =>
      values.lastWhere((size) => width >= size.minWidth);

  bool operator <(WindowSize other) => minWidth < other.minWidth;

  bool operator <=(WindowSize other) => minWidth <= other.minWidth;

  bool operator >(WindowSize other) => minWidth > other.minWidth;

  bool operator >=(WindowSize other) => minWidth >= other.minWidth;
}
