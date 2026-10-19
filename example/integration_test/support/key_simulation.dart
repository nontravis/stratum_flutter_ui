import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Maps [key] to the physical key a device file must pass explicitly.
///
/// `WidgetController.sendKeyEvent` looks up the physical key by
/// `LogicalKeyboardKey.debugName` when none is given, and that getter is
/// assert-gated so it is `null` in profile mode (`event_simulation.dart:692`).
/// Throws [ArgumentError] naming [key] when this map has no entry for it.
PhysicalKeyboardKey physicalKeyFor(LogicalKeyboardKey key) {
  final physicalKey = _physicalKeys[key];
  if (physicalKey == null) {
    // Names the key by its stable `keyId`, never `debugName`: that getter
    // is the one this helper exists to avoid.
    throw ArgumentError(
      'no physical key mapped for logical key '
      '0x${key.keyId.toRadixString(16)}',
    );
  }
  return physicalKey;
}

final Map<LogicalKeyboardKey, PhysicalKeyboardKey> _physicalKeys = {
  LogicalKeyboardKey.tab: PhysicalKeyboardKey.tab,
  LogicalKeyboardKey.escape: PhysicalKeyboardKey.escape,
  LogicalKeyboardKey.f8: PhysicalKeyboardKey.f8,
  LogicalKeyboardKey.altLeft: PhysicalKeyboardKey.altLeft,
  LogicalKeyboardKey.keyT: PhysicalKeyboardKey.keyT,
};

/// Sends [key] down then up, with its physical key attached so the event
/// reaches app code in profile mode too.
Future<void> sendKey(WidgetTester tester, LogicalKeyboardKey key) =>
    tester.sendKeyEvent(key, physicalKey: physicalKeyFor(key));

/// Sends [key] down only, with its physical key attached.
Future<void> sendKeyDown(WidgetTester tester, LogicalKeyboardKey key) =>
    tester.sendKeyDownEvent(key, physicalKey: physicalKeyFor(key));

/// Sends [key] up only, with its physical key attached.
Future<void> sendKeyUp(WidgetTester tester, LogicalKeyboardKey key) =>
    tester.sendKeyUpEvent(key, physicalKey: physicalKeyFor(key));
