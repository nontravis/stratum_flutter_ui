enum FocusType {
  focused,
  focusedVisible,
  none,
  invisible;

  bool get isAnyFocused => isFocused || isFocusedVisible;
  bool get isFocused => this == focused;
  bool get isFocusedVisible => this == focusedVisible;
  bool get isNone => this == none;
  bool get isInvisible => this == invisible;

  bool get isNotFocused => !isFocused;
  bool get isNotFocusedVisible => !isFocusedVisible;
  bool get isNotNone => !isNone;
  bool get isNotInvisible => !isInvisible;
}
