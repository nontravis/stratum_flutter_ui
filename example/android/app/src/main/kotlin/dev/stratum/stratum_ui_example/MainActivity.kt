package dev.stratum.stratum_ui_example

import android.content.res.Configuration
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Channel name the keyboard-visibility device test (US-04 FR-02 E07) reads
 * through; the Dart side lives in
 * `example/integration_test/support/hardware_keyboard.dart`.
 */
private const val HARDWARE_KEYBOARD_CHANNEL_NAME =
    "dev.stratum.stratum_ui_example/hardware_keyboard"

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, HARDWARE_KEYBOARD_CHANNEL_NAME)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "hasHardwareKeyboard" -> result.success(hasHardwareKeyboard())
                    "showImeWithHardKeyboard" -> result.success(showImeWithHardKeyboard())
                    else -> result.notImplemented()
                }
            }
    }

    private fun hasHardwareKeyboard(): Boolean {
        val configuration = resources.configuration
        return configuration.keyboard != Configuration.KEYBOARD_NOKEYS &&
            configuration.hardKeyboardHidden == Configuration.HARDKEYBOARDHIDDEN_NO
    }

    /**
     * Whether `Settings.Secure`'s `show_ime_with_hard_keyboard` is on: the OS
     * policy that decides whether the on-screen keyboard still shows while a
     * hardware keyboard is attached. Read-only here; the host flips it
     * through adb (host-action contract item 4). The 3-arg `getInt` returns
     * the default instead of throwing when the setting is absent.
     */
    private fun showImeWithHardKeyboard(): Boolean {
        return Settings.Secure.getInt(contentResolver, "show_ime_with_hard_keyboard", 0) != 0
    }
}
