enum InputMethod {
  none,
  keyboard,

  /// Touch, mouse, stylus, or trackpad.
  pointer;

  bool get isNone => this == none;
  bool get isKeyboard => this == keyboard;
  bool get isPointer => this == pointer;

  bool get isNotNone => !isNone;
  bool get isNotKeyboard => !isKeyboard;
  bool get isNotPointer => !isPointer;
}
