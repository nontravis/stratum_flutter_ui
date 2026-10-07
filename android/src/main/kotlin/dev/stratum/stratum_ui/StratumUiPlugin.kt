package dev.stratum.stratum_ui

import android.webkit.WebView
import androidx.webkit.WebMessageCompat
import androidx.webkit.WebViewCompat
import androidx.webkit.WebViewFeature
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.webviewflutter.WebViewFlutterAndroidExternalApi

/**
 * The Android half of the native sender channel of `StratumWebView`
 * (docs/specs/stratum_ui/components/common/web_view/s01_architecture.md).
 *
 * `attach` installs the page-side `StratumBridge` object on the WebView that
 * `webview_flutter_android` created for `webViewId` through
 * [WebViewCompat.addWebMessageListener], and forwards every string message
 * with the `sourceOrigin` and `isMainFrame` the platform names. A WebView
 * without `WEB_MESSAGE_LISTENER` answers `false` and gets no object; no
 * JavaScript channel stands in.
 */
class StratumUiPlugin :
    FlutterPlugin,
    MethodChannel.MethodCallHandler {
    private var binding: FlutterPlugin.FlutterPluginBinding? = null
    private var channel: MethodChannel? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        this.binding = binding
        channel =
            MethodChannel(binding.binaryMessenger, CHANNEL).also {
                it.setMethodCallHandler(this)
            }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
        this.binding = null
    }

    override fun onMethodCall(
        call: MethodCall,
        result: MethodChannel.Result,
    ) {
        val id = call.argument<Number>("webViewId")?.toLong()
        if (id == null) {
            result.error("bad-arguments", "webViewId is missing.", null)
            return
        }
        val webView = binding?.let { WebViewFlutterAndroidExternalApi.getWebView(it, id) }
        when (call.method) {
            "attach" ->
                if (webView == null) {
                    result.error("no-web-view", "No WebView has id $id.", null)
                } else {
                    result.success(attach(webView, id))
                }
            "detach" -> {
                // A WebView that is already gone has nothing to detach.
                if (webView != null) detach(webView)
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun attach(
        webView: WebView,
        id: Long,
    ): Boolean {
        if (!WebViewFeature.isFeatureSupported(WebViewFeature.WEB_MESSAGE_LISTENER)) {
            return false
        }
        WebViewCompat.addWebMessageListener(
            webView,
            BRIDGE,
            setOf("*"),
        ) { _, message, sourceOrigin, isMainFrame, _ ->
            if (message.type != WebMessageCompat.TYPE_STRING) return@addWebMessageListener
            channel?.invokeMethod(
                "message",
                mapOf(
                    "webViewId" to id,
                    "data" to message.data,
                    "origin" to sourceOrigin.toString(),
                    "isMainFrame" to isMainFrame,
                ),
            )
        }
        return true
    }

    private fun detach(webView: WebView) {
        if (WebViewFeature.isFeatureSupported(WebViewFeature.WEB_MESSAGE_LISTENER)) {
            WebViewCompat.removeWebMessageListener(webView, BRIDGE)
        }
    }

    private companion object {
        const val CHANNEL = "stratum_ui/web_view_bridge"
        const val BRIDGE = "StratumBridge"
    }
}
