import 'package:flutter/material.dart';
// The package barrel `package:stratum_ui/stratum_ui.dart` does not compile
// yet because of errors outside web_view, so the demo imports the web_view
// barrel directly.
// ignore: implementation_imports
import 'package:stratum_ui/src/components/common/web_view/web_view.dart';

void main() => runApp(const StratumWebViewExampleApp());

class StratumWebViewExampleApp extends StatefulWidget {
  const StratumWebViewExampleApp({super.key});

  @override
  State<StratumWebViewExampleApp> createState() =>
      _StratumWebViewExampleAppState();
}

class _StratumWebViewExampleAppState extends State<StratumWebViewExampleApp> {
  /// Shows Flutter's UI and raster thread graphs over the app.
  var _showOverlay = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      showPerformanceOverlay: _showOverlay,
      home: DefaultTabController(
        length: 3,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('StratumWebView'),
            actions: [
              IconButton(
                icon: const Icon(Icons.speed),
                tooltip: 'Performance overlay',
                isSelected: _showOverlay,
                onPressed: () => setState(() => _showOverlay = !_showOverlay),
              ),
            ],
            bottom: const TabBar(
              tabs: [
                Tab(text: 'URL'),
                Tab(text: 'HTML'),
                Tab(text: 'Bridge'),
              ],
            ),
          ),
          body: const TabBarView(
            physics: NeverScrollableScrollPhysics(),
            children: [_UrlTab(), _HtmlTab(), _BridgeTab()],
          ),
        ),
      ),
    );
  }
}

class _UrlTab extends StatefulWidget {
  const _UrlTab();

  @override
  State<_UrlTab> createState() => _UrlTabState();
}

class _UrlTabState extends State<_UrlTab> {
  final _controller = StratumWebViewController();
  var _loading = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _update(VoidCallback change) {
    if (mounted) setState(change);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () async {
                if (await _controller.canGoBack()) await _controller.goBack();
              },
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _controller.reload,
            ),
            if (_loading)
              const SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            if (_error != null)
              Expanded(child: Text(_error!, overflow: TextOverflow.ellipsis)),
          ],
        ),
        Expanded(
          child: StratumWebView(
            controller: _controller,
            source: StratumWebViewSource.url(Uri.parse('https://flutter.dev')),
            onPageStarted: (_) => _update(() {
              _loading = true;
              _error = null;
            }),
            onPageFinished: (_) => _update(() => _loading = false),
            onError: (error) => _update(
              () => _error = '${error.type.name}: ${error.description}',
            ),
          ),
        ),
      ],
    );
  }
}

class _HtmlTab extends StatelessWidget {
  const _HtmlTab();

  @override
  Widget build(BuildContext context) {
    return const StratumWebView(
      source: StratumWebViewSource.html(
        '<h1 style="font-family: sans-serif">Terms</h1>'
        '<p style="font-family: sans-serif">Rendered from an HTML string.</p>',
      ),
    );
  }
}

const _bridgeHtml = r'''
<!doctype html>
<html>
  <body style="font-family: sans-serif">
    <button id="send">Send to Flutter</button>
    <pre id="log"></pre>
    <script>
      function sendToFlutter(data) {
        if (window.StratumBridge) StratumBridge.postMessage(data);
        else window.parent.postMessage(data, '*');
      }
      let count = 0;
      document.getElementById('send').onclick =
          () => sendToFlutter('page message ' + ++count);
      window.addEventListener('message', (event) => {
        document.getElementById('log').textContent += event.data + '\n';
      });
    </script>
  </body>
</html>
''';

class _BridgeTab extends StatefulWidget {
  const _BridgeTab();

  @override
  State<_BridgeTab> createState() => _BridgeTabState();
}

class _BridgeTabState extends State<_BridgeTab> {
  final _controller = StratumWebViewController();
  final _received = <String>[];
  var _sent = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    _sent++;
    try {
      await _controller.postMessage('flutter message $_sent');
    } on StateError catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              ElevatedButton(
                onPressed: _send,
                child: const Text('Send to page'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _received.isEmpty ? 'No messages yet' : _received.last,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: StratumWebView(
            controller: _controller,
            source: const StratumWebViewSource.html(_bridgeHtml),
            // The bridge stays off while the allowlist is empty, even for
            // HTML content, so it needs at least one entry. Real apps list
            // origins they own here, not a third party's; this demo uses a
            // placeholder app origin only because it has none of its own.
            allowedOrigins: {Uri.parse('https://app.example.com')},
            onMessage: (message) => setState(() => _received.add(message.data)),
          ),
        ),
      ],
    );
  }
}
