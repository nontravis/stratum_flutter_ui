// A page for manually checking Stratum's screen reader speech with VoiceOver,
// TalkBack, or Narrator, by hand:
//
//   flutter run -d <device> -t lib/screen_reader_demo.dart
import 'dart:async';

import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:stratum_ui/stratum_ui.dart';
import 'package:stratum_ui_example/font_licenses.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  registerGoogleFontLicenses();
  runApp(const ScreenReaderDemoApp());
}

/// How long the page-busy check holds, below (F-01 US-13).
const pageLoadingHold = Duration(seconds: 5);

/// How long the splash check holds, below (F-01 US-13).
const splashReplayHold = Duration(seconds: 5);

/// [log] plus [action], cut to the last six, as the demo's own log keeps.
List<String> appendToLog(List<String> log, String action) {
  final next = [...log, action];
  return next.length > 6 ? next.sublist(next.length - 6) : next;
}

/// Holds this demo's checked state, owned and disposed by
/// [_ScreenReaderDemoAppState]. Later checks add their own fields here.
class _DemoChecks extends ChangeNotifier {
  /// The demo's action log, newest last, cut to the last six.
  final log = ValueNotifier<List<String>>(const []);

  /// Check 1's reorderable items, moved by [moveItem].
  final items = ['Item 1', 'Item 2', 'Item 3', 'Item 4', 'Item 5'];

  /// Bumped to replay the splash check with a fresh key.
  var splashRun = 0;

  /// Check 4's divider, opened at 30% so its slider value is checkable.
  final split = SplitLayoutController(fractions: const [0.3, 0.7]);

  /// Whether check 5's page is busy, read by `PageLayout.loading`.
  var pageLoading = false;

  /// Runs while [pageLoading] holds, cleared by [dispose].
  Timer? _pageLoadingTimer;

  /// Check 6's answer to [DemoUpdateChecker], read by the `StratumUpdateGate`
  /// in the `MaterialApp` builder.
  var gateStatus = UpdateStatus.upToDate;

  /// Bumped on every [showGate] and [endGate] call, so the gate's key
  /// changes and each press mounts a fresh gate.
  var gateRun = 0;

  /// Appends [action] to [log] without a notify of this listenable.
  void record(String action) => log.value = appendToLog(log.value, action);

  /// Moves the item at [from] to [to] in [items], as check 1's list
  /// reports a reorder, records the move, and notifies.
  void moveItem(int from, int to) {
    final moved = items.removeAt(from);
    items.insert(to, moved);
    record('$moved moved to position ${to + 1}');
    notifyListeners();
  }

  /// Sets [pageLoading] for [pageLoadingHold], as check 5's button starts.
  void loadPage() {
    pageLoading = true;
    record('Page loading for 5 s');
    notifyListeners();
    _pageLoadingTimer?.cancel();
    _pageLoadingTimer = Timer(pageLoadingHold, () {
      pageLoading = false;
      record('Page loaded');
      notifyListeners();
    });
  }

  /// Sets [gateStatus] to [status] and mounts a fresh gate, as check 6's
  /// buttons start.
  void showGate(UpdateStatus status) {
    gateStatus = status;
    gateRun++;
    record(
      status == UpdateStatus.required
          ? 'Required update screen shown'
          : 'Optional update dialog shown',
    );
    notifyListeners();
  }

  /// Clears [gateStatus] to up to date and mounts a fresh gate, as check 6's
  /// dismiss controls end.
  ///
  /// No-ops after [dispose]: [_OptionalDialogBody]'s own `dispose` schedules
  /// this call for after the frame, which can run past a whole-tree
  /// teardown that happened with the optional dialog still open.
  void endGate(String action) {
    if (_disposed) return;
    gateStatus = UpdateStatus.upToDate;
    gateRun++;
    record(action);
    notifyListeners();
  }

  /// Bumps [splashRun], remounting the splash under a new key so it
  /// preloads and shows its loading frames again, as check 7's button
  /// starts.
  void replaySplash() {
    splashRun++;
    record('Splash shown for 5 s');
    notifyListeners();
  }

  /// Set by [dispose], so [endGate] no-ops once this instance is gone.
  var _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    _pageLoadingTimer?.cancel();
    split.dispose();
    log.dispose();
    super.dispose();
  }
}

/// Check 6's fake [UpdateChecker]: answers [status] at once, with no store,
/// plugin, or backend call.
class DemoUpdateChecker implements UpdateChecker {
  /// Answers [status] on every [check].
  const DemoUpdateChecker(this.status);

  /// The answer [check] gives.
  final UpdateStatus status;

  @override
  Future<UpdateStatus> check() async => status;
}

/// Check 6's screen or dialog for [gate], recording and ending through
/// [checks]. The demo checker never answers [UpdateGateMaintenance].
Widget _gateView(UpdateGateState gate, _DemoChecks checks) => switch (gate) {
  UpdateGateRequired() || UpdateGateMaintenance() => Material(
    child: Center(
      child: ColumnLayout(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Update required'),
          OutlinedButton(
            onPressed: () => checks.endGate('Back to the checks'),
            child: const Text('Back to the checks'),
          ),
        ],
      ),
    ),
  ),
  UpdateGateAvailable(:final dismiss) => Stack(
    children: [
      // Sized to the pane with Positioned.fill: a loose Stack gives this
      // childless box StackFit.loose's smallest constraints, 0x0, and
      // nothing else paints a scrim for this dialog (`barrierColor: null`
      // leaves it to the app).
      const Positioned.fill(child: ColoredBox(color: Color(0x8A000000))),
      Center(
        child: Material(
          child: _OptionalDialogBody(checks: checks, dismiss: dismiss),
        ),
      ),
    ],
  ),
};

/// Check 6's optional-update dialog body. Later (below), Esc, and Android
/// back all leave this body, but only Later calls [_DemoChecks.endGate]
/// itself; [dispose] ends the gate for the other two paths, so
/// [_DemoChecks.gateStatus] never stays available into a splash replay,
/// which would reopen this dialog unasked (FR-01 E06).
class _OptionalDialogBody extends StatefulWidget {
  const _OptionalDialogBody({required this.checks, required this.dismiss});

  /// Ended through [endGate][_DemoChecks.endGate] below.
  final _DemoChecks checks;

  /// Closes this dialog's route; does not end the gate.
  final VoidCallback dismiss;

  @override
  State<_OptionalDialogBody> createState() => _OptionalDialogBodyState();
}

class _OptionalDialogBodyState extends State<_OptionalDialogBody> {
  @override
  void dispose() {
    final checks = widget.checks;
    // Later already ended the gate before this body unmounts, so this
    // guard fires only for Esc and Android back; scheduled after the
    // frame, since the framework is mid-teardown of this element here.
    // checks.endGate itself no-ops if a whole-tree teardown disposes
    // checks before that frame ends.
    if (checks.gateStatus == UpdateStatus.available) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => checks.endGate('Dialog closed'),
      );
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ColumnLayout(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Text('Update available'),
      TextButton(
        onPressed: () {
          widget.dismiss();
          widget.checks.endGate('Later');
        },
        child: const Text('Later'),
      ),
    ],
  );
}

/// The US-13 screen reader checks page, as its own app.
class ScreenReaderDemoApp extends StatefulWidget {
  /// Builds the checks page under its own splash and [MaterialApp].
  const ScreenReaderDemoApp({super.key});

  @override
  State<ScreenReaderDemoApp> createState() => _ScreenReaderDemoAppState();
}

class _ScreenReaderDemoAppState extends State<ScreenReaderDemoApp> {
  final _checks = _DemoChecks();

  @override
  void dispose() {
    _checks.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _checks,
      builder: (context, _) => StratumSplashScreen<void>(
        key: ValueKey(_checks.splashRun),
        themeMode: ThemeMode.light,
        // At launch (splashRun 0) returns at once; a replay (check 7) holds
        // for splashReplayHold so the loading frames stay checkable.
        postload: (context, controller) async {
          if (_checks.splashRun == 0) return;
          await Future<void>.delayed(splashReplayHold);
          _checks.record('Splash done');
        },
        builder: (context, state) => switch (state) {
          StratumSplashLoadingTheme() || StratumSplashLoadingApp() =>
            const ColoredBox(color: Color(0xFFFFFFFF)),
          StratumSplashFailed(:final error) => Center(
            child: ContainerLayout(
              child: Text('The checks failed to start: $error'),
            ),
          ),
          StratumSplashDone(:final controller) => MaterialApp(
            title: 'Stratum screen reader checks',
            supportedLocales: const [Locale('en'), Locale('th')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            builder: (context, child) => StratumThemeApplication.controlled(
              controller: controller,
              themeMode: ThemeMode.light,
              child: StratumUpdateGate(
                key: ValueKey(_checks.gateRun),
                checker: DemoUpdateChecker(_checks.gateStatus),
                builder: (context, gate) => _gateView(gate, _checks),
                child: child!,
              ),
            ),
            home: _ScreenReaderDemoPage(checks: _checks),
          ),
        },
      ),
    );
  }
}

class _ScreenReaderDemoPage extends StatelessWidget {
  const _ScreenReaderDemoPage({required this.checks});

  final _DemoChecks checks;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: checks,
      builder: (context, _) => PageLayout(
        loading: checks.pageLoading,
        header: AppBar(title: const Text('Screen reader checks')),
        left: ColumnLayout(
          style: const WidgetStyle(padding: EdgeInsets.all(24)),
          children: const [Text('Check 3: the start pane.')],
        ),
        drawerCut: WindowSize.bigDesktop,
        onDrawerChanged: (side) =>
            checks.record(side == null ? 'Drawer closed' : 'Drawer opened'),
        body: ColumnLayout(
          style: const WidgetStyle(padding: EdgeInsets.all(24)),
          scroll: const Scroll(),
          crossAxisAlignment: CrossAxisAlignment.start,
          gap: 16,
          children: [
            const Text(
              '1. Reorder. Move to each row of the list below and open its '
              'actions in the screen reader\'s actions menu: each row offers '
              'only the moves it can make. Run "Move down" on "Item 3". '
              'Then, with a hardware keyboard (macOS, or a device with a '
              'keyboard attached), focus "Item 1" and press Alt+Up '
              '(Option+Up on a Mac).',
            ),
            const Text(
              'Expected speech: only the valid move actions on each row; '
              'moving "Item 3" down: "Moved to position 4 of 5"; the '
              'move-up key on the first row: "Already at the start of the '
              'list" (Stratum UI FO-06 US-11 FR-03 E03; FR-06, Scenarios 16 '
              'and 17).',
            ),
            ReorderableListViewLayout.builder(
              shrinkWrap: true,
              primary: false,
              itemCount: checks.items.length,
              itemExtent: 48,
              onReorderItem: checks.moveItem,
              itemBuilder: (context, index) {
                final name = checks.items[index];
                return ContainerLayout(
                  key: ValueKey(name),
                  style: const WidgetStyle(
                    height: 48,
                    padding: EdgeInsetsDirectional.symmetric(horizontal: 12),
                    alignment: AlignmentDirectional.centerStart,
                  ),
                  // A plain Focus, not Interaction: the row needs a
                  // keyboard stop for the reorder keys (FR-01 E07) but no
                  // tap surface, whose own Semantics boundary would split
                  // this label from SliverReorderableList's move actions.
                  child: Focus(child: Text(name)),
                );
              },
            ),
            const Text(
              '2. Modal. Press "Open modal" and swipe through the modal, '
              'then move to the area outside it, and close the modal with '
              'its close button, Esc, or back.',
            ),
            const Text(
              'Expected speech: the built-in dialog or sheet label; the '
              'page behind stays silent; the scrim reads the built-in '
              'dismiss label, none on Windows and Linux; closing returns '
              'focus to the opener (Stratum UI FO-06 US-20 FR-02; FR-06 '
              'E04).',
            ),
            OutlinedButton(
              onPressed: () async {
                checks.record('Modal opened');
                await showModalLayout<void>(
                  context,
                  builder: (context) => const ModalLayout(
                    body: Text('A modal opened with no label passed.'),
                  ),
                );
                checks.record('Modal closed');
              },
              child: const Text('Open modal'),
            ),
            const Text(
              '3. Drawer. Keep the window under 1600 logical px wide: a '
              'phone or a tablet already is; on a Mac, narrow the window. '
              'Press the menu button "Open the drawer" and swipe through '
              'the drawer, then move to the scrim beside it and close the '
              'drawer with the scrim, Esc, or back. At 1600 px or wider the '
              'start pane sits beside the page and nothing opens.',
            ),
            const Text(
              'Expected speech: the built-in drawer label; the scrim reads '
              'dismiss; the page behind stays silent (Stratum UI FO-06 '
              'US-19 FR-05).',
            ),
            Builder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.menu),
                tooltip: 'Open the drawer',
                onPressed: () => PageLayout.of(context).openLeft(),
              ),
            ),
            const Text(
              '4. Divider. Move to the divider between "Start pane" and '
              '"End pane" below, then use the screen reader\'s increase and '
              'decrease actions on it.',
            ),
            const Text(
              'Expected speech: the built-in divider label, "slider", '
              '"30%"; the increase and decrease actions read the new '
              'percent (Stratum UI FO-06 US-21 FR-04 E01; Scenario 4).',
            ),
            SizedBox(
              height: 120,
              width: double.infinity,
              child: SplitLayout(
                controller: checks.split,
                panes: const [
                  SplitPane(child: Text('Start pane')),
                  SplitPane(child: Text('End pane')),
                ],
              ),
            ),
            const Text(
              '5. Page busy. Press "Set the page loading for 5 s" and '
              'listen. The page takes no tap until it has loaded.',
            ),
            const Text(
              'Expected speech: busy, with the built-in loading label '
              '(Stratum UI FO-06 US-18 Scenario 7).',
            ),
            OutlinedButton(
              onPressed: checks.loadPage,
              child: const Text('Set the page loading for 5 s'),
            ),
            const Text(
              '6. Update gate. Press "Show the required update screen" and '
              'listen, then press "Back to the checks". Press "Show the '
              'optional update dialog" and swipe through it, then press '
              '"Later".',
            ),
            const Text(
              'Expected speech: the required full screen opens as its own '
              'screen and is announced; the optional dialog is read alone, '
              'and "Later" closes it (Stratum UI CO-05-09 US-01 FR-02 E06; '
              'US-02 FR-01 E07).',
            ),
            OutlinedButton(
              onPressed: () => checks.showGate(UpdateStatus.required),
              child: const Text('Show the required update screen'),
            ),
            OutlinedButton(
              onPressed: () => checks.showGate(UpdateStatus.available),
              child: const Text('Show the optional update dialog'),
            ),
            const Text(
              '7. Splash. Press "Show the splash for 5 s" and listen. The '
              'checks come back as you left them.',
            ),
            const Text(
              'Expected speech: the loading splash announces "Loading" '
              '(Stratum UI FO-03 US-12 FR-08).',
            ),
            OutlinedButton(
              onPressed: checks.replaySplash,
              child: const Text('Show the splash for 5 s'),
            ),
          ],
        ),
        footer: Padding(
          padding: const EdgeInsets.all(12),
          child: ValueListenableBuilder(
            valueListenable: checks.log,
            builder: (context, actions, _) => Text(
              actions.isEmpty
                  ? 'Log: nothing yet.'
                  : 'Log: ${actions.join('; ')}',
            ),
          ),
        ),
      ),
    );
  }
}
