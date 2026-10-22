import 'dart:async';

import 'package:stratum_ui/stratum_ui.dart';

/// `PageLayout`'s own settings namespace and value name for the left pane's
/// width (`lib/src/components/common/layout/page_layout.dart`
/// `_settingNamespace` and `_leftWidthName`), read here only to prove a
/// settled write landed in the store; `PageLayout` exposes neither itself.
const _pageLayoutNamespace = 'stratum.page_layout';
const _leftWidthName = 'left_width';

/// The width, in logical pixels, the `set_400` control gives the left pane.
///
/// Fits a 360 dp phone window, where a wider pane is cut to the window, and
/// differs from the default left width of 260 or 280.
const pageLayoutFixtureStoredLeftWidth = 300.0;

/// How long a write may take to land in the store before the fixture reports
/// what the store holds instead.
const _landTimeout = Duration(seconds: 10);

/// Pause between two reads of the store while a write is landing.
const _landPoll = Duration(milliseconds: 200);

/// Restart fixture for the left pane width a `PageLayout` remembers.
///
/// A left pane (id `page_layout.left_pane`) that stays inline on every window
/// size, and these controls above it: button `Set left width to 300` (id
/// `page_layout.set_400`) sets [pageLayoutFixtureStoredLeftWidth] through the
/// page's own controller;
/// button `Reset settings` (id `page_layout.reset`) resets the Stratum
/// settings. Text `stored left width: <n|none>` (id `page_layout.stored`)
/// reads a fresh store once the change has landed; text
/// `first frame left width: <n>` (id `page_layout.first_frame_width`) is the
/// left pane's logical width on its first frame.
class PageLayoutFixture extends StatefulWidget {
  /// Opens the fixture over [store], else the default store the real device
  /// keeps between launches.
  const PageLayoutFixture({this.store, super.key});

  /// The store the settings read and write through, or null for the default.
  final StratumWidgetSettingStore? store;

  @override
  State<PageLayoutFixture> createState() => _PageLayoutFixtureState();
}

class _PageLayoutFixtureState extends State<PageLayoutFixture> {
  // MARK: - Properties

  final _pageController = PageLayoutController();

  /// The settings the page reads; null until the store has loaded, so the
  /// page's first frame already holds the remembered width.
  StratumWidgetSettingsController? _settings;

  /// The left pane's width at its first layout; null until it has one.
  double? _firstFrameWidth;

  /// The width a fresh store holds, null for none.
  double? _stored;

  /// Tells a newer store read from an older one still polling.
  var _readToken = 0;

  // MARK: - Lifecycle

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _readToken++;
    _pageController.dispose();
    _settings?.dispose();
    super.dispose();
  }

  // MARK: - Build

  @override
  Widget build(BuildContext context) {
    final settings = _settings;
    if (settings == null) return const SizedBox.shrink();
    return StratumWidgetSettings(
      controller: settings,
      child: PageLayout(
        setting: const WidgetSettingKey.global(),
        controller: _pageController,
        // The smallest window size, so no window size puts the pane in a
        // drawer; a phone shows it inline too.
        drawerCut: WindowSize.watch,
        minCenterWidth: 0,
        header: ColumnLayout(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              identifier: 'page_layout.set_400',
              button: true,
              child: FilledButton(
                onPressed: _setLeftWidth,
                child: Text(
                  'Set left width to ${_format(pageLayoutFixtureStoredLeftWidth)}',
                ),
              ),
            ),
            Semantics(
              identifier: 'page_layout.reset',
              button: true,
              child: FilledButton(
                onPressed: _resetSettings,
                child: const Text('Reset settings'),
              ),
            ),
            Semantics(
              identifier: 'page_layout.stored',
              child: Text('stored left width: ${_format(_stored)}'),
            ),
            Semantics(
              identifier: 'page_layout.first_frame_width',
              child: Text(
                'first frame left width: ${_format(_firstFrameWidth)}',
              ),
            ),
          ],
        ),
        left: LayoutBuilder(
          builder: (context, constraints) {
            _recordFirstFrame(constraints.maxWidth);
            return Semantics(
              identifier: 'page_layout.left_pane',
              child: const ColoredBox(color: Color(0xFFE0E0E0)),
            );
          },
        ),
      ),
    );
  }

  // MARK: - Event Handlers

  void _setLeftWidth() {
    _pageController.leftWidth = pageLayoutFixtureStoredLeftWidth;
    unawaited(_readUntilStored(pageLayoutFixtureStoredLeftWidth));
  }

  Future<void> _resetSettings() async {
    final token = ++_readToken;
    await _settings?.resetAll();
    final stored = await _readStored();
    if (!mounted || token != _readToken) return;
    setState(() => _stored = stored);
  }

  // MARK: - Private Methods

  Future<void> _load() async {
    final settings = await StratumWidgetSettingsController.preload(
      store: widget.store,
    );
    if (!mounted) {
      settings.dispose();
      return;
    }
    final stored = await _readStored();
    if (!mounted) {
      settings.dispose();
      return;
    }
    setState(() {
      _settings = settings;
      _stored = stored;
    });
  }

  /// Keeps the width of the first layout, then shows it once that frame ends.
  void _recordFirstFrame(double width) {
    if (_firstFrameWidth != null) return;
    _firstFrameWidth = width;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  /// Reads a fresh store until it holds [expected], or [_landTimeout] ends.
  ///
  /// The page saves a settled width without awaiting it, so no handle here
  /// can await the write itself.
  Future<void> _readUntilStored(double expected) async {
    final token = ++_readToken;
    final deadline = DateTime.now().add(_landTimeout);
    var stored = await _readStored();
    while (stored != expected && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(_landPoll);
      if (!mounted || token != _readToken) return;
      stored = await _readStored();
    }
    if (!mounted || token != _readToken) return;
    setState(() => _stored = stored);
  }

  /// The left pane width a fresh controller reads from the store.
  Future<double?> _readStored() async {
    final prover = await StratumWidgetSettingsController.preload(
      store: widget.store,
    );
    try {
      return prover.box(_pageLayoutNamespace).global.getDouble(_leftWidthName);
    } finally {
      prover.dispose();
    }
  }

  /// A whole width without a decimal point, else the width as it is.
  String _format(double? width) {
    if (width == null) return 'none';
    return width == width.roundToDouble()
        ? width.toStringAsFixed(0)
        : width.toString();
  }
}
