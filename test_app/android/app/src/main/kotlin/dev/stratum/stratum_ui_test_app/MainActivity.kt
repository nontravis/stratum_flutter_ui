package dev.stratum.stratum_ui_test_app

import androidx.webkit.WebViewCompat
import androidx.webkit.WebViewFeature
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // The device tests' own oracle for the WebView bridge: it asks the
        // system WebView directly, so it shares nothing with stratum_ui's code.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, WEB_VIEW_FEATURES_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "bridgeFeatures" -> result.success(bridgeFeatures())
                    else -> result.notImplemented()
                }
            }
    }

    private fun bridgeFeatures(): Map<String, Any?> =
        mapOf(
            "webMessageListener" to
                WebViewFeature.isFeatureSupported(WebViewFeature.WEB_MESSAGE_LISTENER),
            "jsInjectionInFrameAndWorld" to
                WebViewFeature.isFeatureSupported(
                    WebViewFeature.JS_INJECTION_IN_FRAME_AND_WORLD,
                ),
            "versionName" to WebViewCompat.getCurrentWebViewPackage(this)?.versionName,
        )

    private companion object {
        const val WEB_VIEW_FEATURES_CHANNEL = "dev.stratum.stratum_ui_test_app/web_view_features"
    }
}
