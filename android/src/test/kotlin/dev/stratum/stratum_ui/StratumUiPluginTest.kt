package dev.stratum.stratum_ui

import android.webkit.WebView
import androidx.webkit.WebViewCompat
import androidx.webkit.WebViewFeature
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.webviewflutter.WebViewFlutterAndroidExternalApi
import kotlin.test.Test
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
}
