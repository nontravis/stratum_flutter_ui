import 'package:stratum_ui/stratum_ui.dart';

/// Address the `URL` tab loads when the fixture opens without one.
final _defaultAddress = Uri.parse('https://flutter.dev');

/// HTML the `Bridge` tab loads: a button that posts `page message <n>` to the
/// app, and a log of every message the app sends to the page.
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

/// Web view fixture with three tabs, the page the integration legs of
/// CO-01-02 US-01 to US-04 (`Device legs`) walk.
///
/// Tabs `URL`, `HTML`, and `Bridge` (their labels are the finders; none
/// carries an id, since a semantics identifier would split a tab's label,
/// role, and tap onto two nodes). The `URL` tab loads [urlAddress], else
/// `https://flutter.dev`, under a back button, a reload button, a spinner
/// while a load runs, and the line `<type>: <description>` after a failed
/// load. The `HTML` tab renders a fixed document. The `Bridge` tab shows
/// button `Send to page` and the text `No messages yet`, or the last message
/// the page sent, over a web view that holds a page with its own send
/// button; `Send to page` shows a snack bar when the bridge refuses the send.
class WebViewFixture extends StatelessWidget {
  const WebViewFixture({this.urlAddress, super.key});

  /// Address the `URL` tab loads, or null for `https://flutter.dev`.
  final Uri? urlAddress;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: ColumnLayout(
        children: [
          const TabBar(
            tabs: [
              Tab(text: 'URL'),
              Tab(text: 'HTML'),
              Tab(text: 'Bridge'),
            ],
          ),
          Expanded(
            child: TabBarView(
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _UrlTab(urlAddress: urlAddress ?? _defaultAddress),
                const _HtmlTab(),
                const _BridgeTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UrlTab extends StatefulWidget {
  const _UrlTab({required this.urlAddress});

  final Uri urlAddress;

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

  @override
  Widget build(BuildContext context) {
    return ColumnLayout(
      children: [
        RowLayout(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              tooltip: 'Go back',
              onPressed: () async {
                if (await _controller.canGoBack()) await _controller.goBack();
              },
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Reload',
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
            source: StratumWebViewSource.url(widget.urlAddress),
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

  void _update(VoidCallback change) {
    if (mounted) setState(change);
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

  @override
  Widget build(BuildContext context) {
    return ColumnLayout(
      children: [
        ContainerLayout(
          style: const WidgetStyle(padding: EdgeInsets.all(8)),
          child: RowLayout(
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
            // origins they own here, not a third party's; this fixture uses a
            // placeholder app origin only because it has none of its own.
            allowedOrigins: {Uri.parse('https://app.example.com')},
            onMessage: (message) => setState(() => _received.add(message.data)),
          ),
        ),
      ],
    );
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
}
