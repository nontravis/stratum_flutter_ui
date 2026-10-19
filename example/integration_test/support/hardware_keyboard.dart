import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// The channel the example app's own Android (`MainActivity.kt`) and iOS
/// (`AppDelegate.swift`) host code answers; only those two hosts register a
/// handler, so a caller checks the platform before invoking it.
const MethodChannel _hardwareKeyboardChannel = MethodChannel(
  'dev.stratum.stratum_ui_example/hardware_keyboard',
);

/// How long a call through [_hardwareKeyboardChannel] waits for the native
/// host to answer before failing, so a stuck native handler cannot block
/// the test indefinitely.
const _channelTimeout = Duration(seconds: 10);

/// Invokes [method] on [_hardwareKeyboardChannel], failing naming both the
/// channel and [method] after [_channelTimeout] with no answer.
Future<bool> _invokeBool(String method) async {
  final result = await _hardwareKeyboardChannel
      .invokeMethod<bool>(method)
      .timeout(
        _channelTimeout,
        onTimeout: () => fail(
          'dev.stratum.stratum_ui_example/hardware_keyboard timed out '
          'after ${_channelTimeout.inSeconds}s calling $method',
        ),
      );
  return result ?? false;
}

/// Whether the host reports a hardware keyboard attached and visible to the
/// OS (US-04 FR-02 E07): Android reads `resources.configuration.keyboard`
/// and `hardKeyboardHidden`; iOS reads `GCKeyboard.coalesced`.
///
/// Fails naming the channel after 10 s with no answer.
Future<bool> hasHardwareKeyboard() => _invokeBool('hasHardwareKeyboard');

/// Whether Android's `Settings.Secure` `show_ime_with_hard_keyboard` is on:
/// the read-only OS policy that decides whether the on-screen keyboard
/// still shows while a hardware keyboard is attached.
///
/// Owner ruling 2026-10-18 (DR13-r3 `pixel_2`): this policy, never
/// "hardware keyboard attached" alone, decides E02 vs E07 on Android — the
/// device reported a hardware keyboard and this setting on, and the
/// library correctly showed the on-screen keyboard anyway. Android only;
/// iOS has no such setting and never answers this method. Fails naming the
/// channel after 10 s with no answer.
Future<bool> showImeWithHardKeyboard() =>
    _invokeBool('showImeWithHardKeyboard');
