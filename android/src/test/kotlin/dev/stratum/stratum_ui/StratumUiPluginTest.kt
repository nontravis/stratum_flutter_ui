package dev.stratum.stratum_ui

import android.net.Uri
import android.webkit.WebView
import androidx.webkit.JavaScriptReplyProxy
import androidx.webkit.WebMessageCompat
import androidx.webkit.WebViewCompat
import androidx.webkit.WebViewFeature
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.webviewflutter.WebViewFlutterAndroidExternalApi
import kotlin.test.Test
import kotlin.test.assertNotNull
import org.mockito.ArgumentMatchers.any
import org.mockito.ArgumentMatchers.anySet
import org.mockito.ArgumentMatchers.anyString
import org.mockito.MockedStatic
import org.mockito.Mockito

internal class StratumUiPluginTest {
    private val binding =
        Mockito.mock(FlutterPlugin.FlutterPluginBinding::class.java).also {
            Mockito.`when`(it.binaryMessenger).thenReturn(Mockito.mock(BinaryMessenger::class.java))
        }
    private val first = Mockito.mock(WebView::class.java)
    private val second = Mockito.mock(WebView::class.java)

    private fun withPlatform(
        supported: Boolean = true,
        body: (MockedStatic<WebViewCompat>) -> Unit,
    ) {
        Mockito.mockStatic(WebViewFeature::class.java).use { feature ->
            feature.`when`<Boolean> { WebViewFeature.isFeatureSupported(anyString()) }.thenReturn(supported)
            Mockito.mockStatic(WebViewFlutterAndroidExternalApi::class.java).use { api ->
                api.`when`<WebView?> { WebViewFlutterAndroidExternalApi.getWebView(binding, 1L) }.thenReturn(first)
                api.`when`<WebView?> { WebViewFlutterAndroidExternalApi.getWebView(binding, 2L) }.thenReturn(second)
                Mockito.mockStatic(WebViewCompat::class.java).use(body)
            }
        }
    }

    private fun StratumUiPlugin.call(
        method: String,
        id: Long,
    ): MethodChannel.Result =
        Mockito.mock(MethodChannel.Result::class.java).also {
            onMethodCall(MethodCall(method, mapOf("webViewId" to id)), it)
        }

    private fun StratumUiPlugin.callWith(
        method: String,
        arguments: Map<String, Any?>?,
    ): MethodChannel.Result =
        Mockito.mock(MethodChannel.Result::class.java).also {
            onMethodCall(MethodCall(method, arguments), it)
        }

    /** Makes [compat] keep the bridge listener `attach` installs. */
    private fun keepListener(
        compat: MockedStatic<WebViewCompat>,
    ): () -> WebViewCompat.WebMessageListener? {
        var listener: WebViewCompat.WebMessageListener? = null
        compat
            .`when`<Unit> {
                WebViewCompat.addWebMessageListener(
                    any(WebView::class.java),
                    anyString(),
                    anySet(),
                    any(WebViewCompat.WebMessageListener::class.java),
                )
            }.thenAnswer {
                listener = it.getArgument(3)
                null
            }
        return { listener }
    }

    /** Posts a string message from the main frame of [view], which gives it a reply proxy. */
    private fun deliverMainFrameMessage(
        listener: WebViewCompat.WebMessageListener?,
        view: WebView,
    ) {
        assertNotNull(listener).onPostMessage(
            view,
            Mockito.mock(WebMessageCompat::class.java),
            Mockito.mock(Uri::class.java),
            true,
            Mockito.mock(JavaScriptReplyProxy::class.java),
        )
    }

    @Test
    fun engineDetach_removesTheBridgeListenerFromEveryAttachedWebView() =
        withPlatform { compat ->
            val plugin = StratumUiPlugin()
            plugin.onAttachedToEngine(binding)
            plugin.call("attach", 1L)
            plugin.call("attach", 2L)
            plugin.onDetachedFromEngine(binding)
            compat.verify { WebViewCompat.removeWebMessageListener(first, "StratumBridge") }
            compat.verify { WebViewCompat.removeWebMessageListener(second, "StratumBridge") }
        }

    @Test
    fun detachedWebView_isNotDetachedAgainWithTheEngine() =
        withPlatform { compat ->
            val plugin = StratumUiPlugin()
            plugin.onAttachedToEngine(binding)
            plugin.call("attach", 1L)
            plugin.call("detach", 1L)
            plugin.onDetachedFromEngine(binding)
            compat.verify(
                { WebViewCompat.removeWebMessageListener(first, "StratumBridge") },
                Mockito.times(1),
            )
        }

    @Test
    fun attachWithoutTheFeatures_answersFalseAndInstallsNothing() =
        withPlatform(supported = false) { compat ->
            val plugin = StratumUiPlugin()
            plugin.onAttachedToEngine(binding)
            val result = plugin.call("attach", 1L)
            Mockito.verify(result).success(false)
            compat.verifyNoInteractions()
        }

    @Test
    fun reset_removesTheBridgeListenerFromEveryAttachedWebViewAndAnswersSuccess() =
        withPlatform { compat ->
            val plugin = StratumUiPlugin()
            plugin.onAttachedToEngine(binding)
            plugin.call("attach", 1L)
            plugin.call("attach", 2L)
            val result = plugin.callWith("reset", null)
            Mockito.verify(result).success(null)
            compat.verify { WebViewCompat.removeWebMessageListener(first, "StratumBridge") }
            compat.verify { WebViewCompat.removeWebMessageListener(second, "StratumBridge") }
        }

    @Test
    fun staleReplyProxyId_answersReplyProxyGoneAfterReset() =
        withPlatform { compat ->
            val listener = keepListener(compat)
            val plugin = StratumUiPlugin()
            plugin.onAttachedToEngine(binding)
            plugin.call("attach", 1L)
            // The first reply proxy of a plugin gets id 0.
            deliverMainFrameMessage(listener(), first)
            val script = mapOf("webViewId" to 1L, "replyProxy" to 0L, "script" to "true")
            val live = plugin.callWith("runThroughReplyProxy", script)
            Mockito.verify(live, Mockito.never()).error(anyString(), any(), any())
            plugin.callWith("reset", null)
            val stale = plugin.callWith("runThroughReplyProxy", script)
            Mockito.verify(stale).error(Mockito.eq("reply-proxy-gone"), anyString(), Mockito.isNull())
        }

    @Test
    fun webViewIdUsedAgainAfterReset_attachesFresh() =
        withPlatform { compat ->
            val plugin = StratumUiPlugin()
            plugin.onAttachedToEngine(binding)
            plugin.call("attach", 1L)
            plugin.callWith("reset", null)
            val result = plugin.call("attach", 1L)
            Mockito.verify(result).success(true)
            compat.verify(
                {
                    WebViewCompat.addWebMessageListener(
                        Mockito.eq(first),
                        Mockito.eq("StratumBridge"),
                        anySet(),
                        any(WebViewCompat.WebMessageListener::class.java),
                    )
                },
                Mockito.times(2),
            )
            plugin.onDetachedFromEngine(binding)
            compat.verify(
                { WebViewCompat.removeWebMessageListener(first, "StratumBridge") },
                Mockito.times(2),
            )
        }

    @Test
    fun resetWithoutAnAttachedWebView_answersSuccess() =
        withPlatform { compat ->
            val plugin = StratumUiPlugin()
            plugin.onAttachedToEngine(binding)
            val result = plugin.callWith("reset", null)
            Mockito.verify(result).success(null)
            compat.verifyNoInteractions()
        }

    @Test
    fun reset_forgetsEverythingEvenWhenOneWebViewRefusesTheRemoval() =
        withPlatform { compat ->
            compat
                .`when`<Unit> { WebViewCompat.removeWebMessageListener(first, "StratumBridge") }
                .thenThrow(IllegalStateException("refused"))
            val listener = keepListener(compat)
            val plugin = StratumUiPlugin()
            plugin.onAttachedToEngine(binding)
            plugin.call("attach", 1L)
            plugin.call("attach", 2L)
            deliverMainFrameMessage(listener(), first)
            val result = plugin.callWith("reset", null)
            Mockito.verify(result).success(null)
            compat.verify { WebViewCompat.removeWebMessageListener(second, "StratumBridge") }
            val stale = plugin.callWith("runThroughReplyProxy", proxyCall(1L, 0L))
            Mockito.verify(stale).error(Mockito.eq("reply-proxy-gone"), anyString(), Mockito.isNull())
        }

    @Test
    fun messageFromAWebViewThatIsNotAttachedUnderItsId_isDropped() =
        withPlatform { compat ->
            val listener = keepListener(compat)
            val plugin = StratumUiPlugin()
            plugin.onAttachedToEngine(binding)
            plugin.call("attach", 1L)
            plugin.callWith("reset", null)
            // The listener a reset could not reach still posts under id 1.
            deliverMainFrameMessage(listener(), first)
            val result = plugin.callWith("runThroughReplyProxy", proxyCall(1L, 0L))
            Mockito.verify(result).error(Mockito.eq("reply-proxy-gone"), anyString(), Mockito.isNull())
        }

    private fun proxyCall(
        id: Long,
        proxyId: Long,
    ) = mapOf("webViewId" to id, "replyProxy" to proxyId, "script" to "true")
}
