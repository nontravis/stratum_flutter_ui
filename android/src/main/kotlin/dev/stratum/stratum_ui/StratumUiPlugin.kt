package dev.stratum.stratum_ui

import android.webkit.WebView
import androidx.webkit.JavaScriptExecutionException
import androidx.webkit.JavaScriptReplyProxy
import androidx.webkit.WebMessageCompat
import androidx.webkit.WebViewCompat
import androidx.webkit.WebViewFeature
import androidx.webkit.WebViewOutcomeReceiver
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
 * without `WEB_MESSAGE_LISTENER` or `JS_INJECTION_IN_FRAME_AND_WORLD`
 * answers `false` and gets no object; no JavaScript channel stands in.
 *
 * A main-frame message also carries the id of its sender's
 * [JavaScriptReplyProxy], and `runThroughReplyProxy` runs a script through
 * that proxy, which the platform runs only in the document that sent it.
 */
class StratumUiPlugin :
    FlutterPlugin,
    MethodChannel.MethodCallHandler {
    private var binding: FlutterPlugin.FlutterPluginBinding? = null
    private var channel: MethodChannel? = null

    /**
     * The reply proxy of the latest main-frame message of each WebView, by
     * `webViewId`. One main-frame document is live at a time, so a proxy an
     * older document handed is gone with it.
     */
    private val replyProxies = mutableMapOf<Long, ReplyProxy>()
    private var nextReplyProxyId = 0L

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
        replyProxies.clear()
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
        when (call.method) {
            "attach" -> {
                val webView = webView(id)
                if (webView == null) {
                    result.error("no-web-view", "No WebView has id $id.", null)
                } else {
                    result.success(attach(webView, id))
                }
            }
            "detach" -> {
                // A WebView that is already gone has nothing to detach.
                webView(id)?.let(::detach)
                replyProxies.remove(id)
                result.success(null)
            }
            "runThroughReplyProxy" -> runThroughReplyProxy(call, id, result)
            else -> result.notImplemented()
        }
    }

    private fun webView(id: Long): WebView? =
        binding?.let { WebViewFlutterAndroidExternalApi.getWebView(it, id) }

    private fun attach(
        webView: WebView,
        id: Long,
    ): Boolean {
        if (!WebViewFeature.isFeatureSupported(WebViewFeature.WEB_MESSAGE_LISTENER) ||
            !WebViewFeature.isFeatureSupported(WebViewFeature.JS_INJECTION_IN_FRAME_AND_WORLD)
        ) {
            return false
        }
        WebViewCompat.addWebMessageListener(
            webView,
            BRIDGE,
            setOf("*"),
        ) { _, message, sourceOrigin, isMainFrame, replyProxy ->
            if (message.type != WebMessageCompat.TYPE_STRING) return@addWebMessageListener
            channel?.invokeMethod(
                "message",
                mapOf(
                    "webViewId" to id,
                    "data" to message.data,
                    // An opaque origin serializes as "null"; it crosses as
                    // null, as on iOS and macOS.
                    "origin" to sourceOrigin.toString().takeUnless { it == "null" },
                    "isMainFrame" to isMainFrame,
                    "replyProxy" to if (isMainFrame) replyProxyId(id, replyProxy) else null,
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

    /**
     * The id of [proxy], which becomes the latest of WebView [id]. The
     * platform hands one proxy per document, so the messages of one document
     * share an id.
     */
    private fun replyProxyId(
        id: Long,
        proxy: JavaScriptReplyProxy,
    ): Long {
        val latest = replyProxies[id]
        if (latest != null && latest.proxy === proxy) return latest.id
        return ReplyProxy(nextReplyProxyId++, proxy).also { replyProxies[id] = it }.id
    }

    /**
     * Runs `script` through the reply proxy `replyProxy` names and answers
     * whether the script returned `true`. Answers an error when that proxy is
     * no longer the latest of the WebView, when its document is gone
     * (`FRAME_DESTROYED`), or when the script fails; the platform may never
     * answer for a document that is unloading, so Dart bounds the wait. Runs
     * on the main thread, which [JavaScriptReplyProxy] requires.
     */
    private fun runThroughReplyProxy(
        call: MethodCall,
        id: Long,
        reply: MethodChannel.Result,
    ) {
        val proxyId = call.argument<Number>("replyProxy")?.toLong()
        val script = call.argument<String>("script")
        if (proxyId == null || script == null) {
            reply.error("bad-arguments", "replyProxy or script is missing.", null)
            return
        }
        val latest = replyProxies[id]
        if (latest == null || latest.id != proxyId) {
            reply.error("reply-proxy-gone", "The document of reply proxy $proxyId is gone.", null)
            return
        }
        latest.proxy.executeJavaScript(
            script,
            object : WebViewOutcomeReceiver<String, JavaScriptExecutionException> {
                override fun onResult(result: String?) = reply.success(result == "true")

                override fun onError(error: JavaScriptExecutionException) {
                    val code =
                        if (error.errorType == JavaScriptExecutionException.ERROR_FRAME_DESTROYED) {
                            "frame-destroyed"
                        } else {
                            "script-failed"
                        }
                    reply.error(code, error.message, null)
                }
            },
        )
    }

    /** A reply proxy and the id Dart refers to it by. */
    private class ReplyProxy(
        val id: Long,
        val proxy: JavaScriptReplyProxy,
    )

    private companion object {
        const val CHANNEL = "stratum_ui/web_view_bridge"
        const val BRIDGE = "StratumBridge"
    }
}
