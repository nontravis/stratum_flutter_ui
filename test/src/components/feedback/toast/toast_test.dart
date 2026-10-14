import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/components/feedback/toast/toast_plain_look.dart'
    show toastCloseTime;
import 'package:stratum_ui/src/src.dart';

import '../../../themes/system/system_style_fakes.dart';
import '../../common/fakes/fake_stratum_theme.dart';

// The Build Gate rows (stratum-create-widget) of the plain look, plus the
// close rules (FR-04), the announcement (FR-05), and the style layers
// (FR-06) of US-01. The host's placement, queue, and stack behavior sit in
// toast_host_test.dart.

void _noop() {}

const _phone = Size(390, 844);

const _white = Color(0xFFFFFFFF);

/// A phone-sized test view, logical pixels, reset after the test (P2, N4).
void _view(WidgetTester tester) {
  tester.view.physicalSize = _phone;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// [home] under the theme and the toast host above the app's navigator,
/// with the view's media data edited by [media] so an outer test flag
/// reaches the host (N5), in [direction], else LTR.
Widget _app(
  Widget? home, {
  MediaQueryData Function(MediaQueryData data)? media,
  TextDirection direction = TextDirection.ltr,
  Locale locale = const Locale('en'),
  StratumHighContrastMode highContrast = StratumHighContrastMode.system,
  StratumComponentPartDefaultsBuilder? componentPartDefaults,
}) => MaterialApp(
  locale: locale,
  supportedLocales: const [Locale('en'), Locale('th'), Locale('ja')],
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  builder: (context, child) {
    final app = StratumThemeApplication(
      themes: StratumThemeSet(light: fakeTheme),
      themeMode: ThemeMode.light,
      highContrast: highContrast,
      componentPartDefaults: componentPartDefaults,
      child: Directionality(
        textDirection: direction,
        child: StratumToastHost(child: child!),
      ),
    );
    return media == null
        ? app
        : MediaQuery(data: media(MediaQuery.of(context)), child: app);
  },
  home: Scaffold(body: home ?? const SizedBox()),
);

/// A button labeled [label] whose tap runs [show] with its context.
Widget _button(String label, void Function(BuildContext) show) => Builder(
  builder: (c) => TextButton(onPressed: () => show(c), child: Text(label)),
);

/// The surface box of the notice holding [message]: the outermost
/// `ContainerLayout` under it.
Finder _fill(String message) => find
    .ancestor(of: find.text(message), matching: find.byType(ContainerLayout))
    .last;

/// Runs [body] with [defaultTargetPlatform] overridden to [platform],
/// restored before this returns (`ink_well_test.dart`'s pattern: try/finally,
/// never `addTearDown`, which runs after the framework's own invariant
/// check).
Future<void> _withTargetPlatform(
  TargetPlatform platform,
  Future<void> Function() body,
) async {
  debugDefaultTargetPlatformOverride = platform;
  try {
    await body();
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}

/// [home] on a route whose own edge is `leaveFlutterView`, the value
/// `WidgetsApp` sets on the web (probe-tab findings, table row 3), so Tab
/// cannot reach a notice and only the host shortcut can.
Widget _webEdgeApp(Widget home) => MaterialApp(
  builder: (context, child) => StratumThemeApplication(
    themes: StratumThemeSet(light: fakeTheme),
    themeMode: ThemeMode.light,
    child: StratumToastHost(child: child!),
  ),
  onGenerateRoute: (settings) => MaterialPageRoute<void>(
    settings: settings,
    traversalEdgeBehavior: TraversalEdgeBehavior.leaveFlutterView,
    builder: (_) => Scaffold(body: home),
  ),
);

/// Requests focus on the node labeled [label] through its semantics
/// `focus` action, never a tap: a tap on the notice's own buttons closes
/// it (its action and close paths both call `notice.close()`), so this is
/// the only pointer-free way a keyboard-first user's first Tab could
/// already sit inside the notice.
void _focusViaSemantics(WidgetTester tester, String label) {
  final id = tester.getSemantics(find.bySemanticsLabel(label)).id;
  tester.binding.renderViews.single.owner!.semanticsOwner!.performAction(
    id,
    SemanticsAction.focus,
  );
}

/// Records every `announce` message of [SystemChannels.accessibility],
/// skipping the `tap` feedback messages a button press also sends (N6).
List<String> _announceRecorder(WidgetTester tester) {
  final announced = <String>[];
  tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<Object?>(
    SystemChannels.accessibility,
    (message) async {
      final map = message! as Map;
      if (map['type'] == 'announce') {
        announced.add((map['data'] as Map)['message'] as String);
      }
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger
        .setMockDecodedMessageHandler<Object?>(
          SystemChannels.accessibility,
          null,
        ),
  );
  return announced;
}

/// A light-headered (or, on [edge] bottom, light-footered) page whose host
/// can show a dark solid notice on [edge] (`go`), a gradient one
/// (`gradient`), or an app-builder one (`mine`), for the fill the notice
/// declares under the status or navigation bar. [builder] replaces the
/// look of every notice when set; [goStyle] overrides the `go` notice.
Widget _systemApp({
  StratumToastBuilder? builder,
  WidgetStyle? goStyle,
  StratumToastEdge edge = StratumToastEdge.top,
  bool pageBars = true,
}) {
  final placement = StratumToastPlacement.solid(edge);
  final top = edge == StratumToastEdge.top;
  return MaterialApp(
    builder: (context, child) => StratumThemeApplication(
      themes: defaultThemeSet,
      themeMode: ThemeMode.light,
      child: StratumToastHost(builder: builder, child: child!),
    ),
    home: Scaffold(
      body: PageLayout(
        header: top && pageBars ? const SizedBox() : null,
        footer: !top && pageBars ? const SizedBox() : null,
        customStyle: PageLayoutStyle(
          header: top && pageBars
              ? const WidgetStyle(backgroundColor: _white)
              : null,
          footer: !top && pageBars
              ? const WidgetStyle(backgroundColor: _white)
              : null,
        ),
        body: ColumnLayout(
          children: [
            _button('go', (c) {
              c.showToast(
                message: 'Top',
                placement: placement,
                customStyle: goStyle,
              );
            }),
            _button('gradient', (c) {
              c.showToast(
                message: 'Grad',
                placement: placement,
                customStyle: const WidgetStyle(
                  backgroundGradient: LinearGradient(
                    colors: [Color(0xFF000000), Color(0xFFFFFFFF)],
                  ),
                ),
              );
            }),
            _button('mine', (c) {
              c.showToast(message: 'Mine', placement: placement);
            }),
          ],
        ),
      ),
    ),
  );
}

void main() {
  test('us01/fr04: close times', () {
    expect(
      toastCloseTime(hasAction: false, screenReader: false),
      const Duration(seconds: 4),
    );
    expect(
      toastCloseTime(hasAction: true, screenReader: false),
      const Duration(seconds: 8),
    );
    expect(
      toastCloseTime(hasAction: true, screenReader: true),
      isNull, // fr04/e01
    );
    expect(
      toastCloseTime(hasAction: false, screenReader: true),
      const Duration(seconds: 4), // fr04/e02
    );
  });

  const undo = StratumToastAction(label: 'Undo', onPressed: _noop);

  testWidgets('us01/s6: a notice with an action closes after 8 s', (
    tester,
  ) async {
    _view(tester);
    await tester.pumpWidget(
      _app(
        _button(
          'go',
          (c) => c.showToast(message: 'Item deleted', action: undo),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 5));
    expect(find.text('Item deleted'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text('Item deleted'), findsNothing);
  });

  testWidgets('us01/s7: the pointer resting on it pauses the timer', (
    tester,
  ) async {
    _view(tester);
    await tester.pumpWidget(
      _app(_button('go', (c) => c.showToast(message: 'Hold'))),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: tester.getCenter(find.text('Hold')));
    await tester.pump(const Duration(seconds: 6));
    expect(find.text('Hold'), findsOneWidget);
    await mouse.moveTo(Offset.zero);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(find.text('Hold'), findsNothing);
  });

  testWidgets(
    'n16: hover then focus pause the timer; it resumes only once both end',
    (tester) async {
      _view(tester);
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(_button('go', (c) => c.showToast(message: 'Both', action: undo))),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: tester.getCenter(find.text('Both')));
      _focusViaSemantics(tester, 'Undo');
      await tester.pump();
      // The pointer leaves first, with focus still held; a regression
      // that resets the whole pause set on any single `_resume` call,
      // instead of removing only the one reason that ended, would wrongly
      // let the full 8 s close time run out here.
      await mouse.moveTo(Offset.zero);
      await tester.pump(const Duration(seconds: 9));
      expect(find.text('Both'), findsOneWidget);
      // Focus leaves too; only now does every reason end and the timer
      // resumes, running out its full remaining time (nothing counted
      // down while it sat paused).
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump(const Duration(seconds: 9));
      await tester.pumpAndSettle();
      expect(find.text('Both'), findsNothing);
      handle.dispose();
    },
  );

  testWidgets('us01/s8: us01/fr04/e01: held while a screen reader runs', (
    tester,
  ) async {
    _view(tester);
    await tester.pumpWidget(
      _app(
        _button(
          'go',
          (c) => c.showToast(message: 'Item deleted', action: undo),
        ),
        media: (data) => data.copyWith(accessibleNavigation: true),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 30));
    expect(find.text('Item deleted'), findsOneWidget);
  });

  testWidgets('us01/s11: the action runs and the notice closes', (
    tester,
  ) async {
    _view(tester);
    var undone = 0;
    await tester.pumpWidget(
      _app(
        _button(
          'go',
          (c) => c.showToast(
            message: 'Item deleted',
            action: StratumToastAction(
              label: 'Undo',
              onPressed: () => undone++,
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(undone, 1);
    expect(find.text('Item deleted'), findsNothing);
  });

  testWidgets(
    'us01/s12: us01/fr04/e04: Esc on the focused close button closes it; '
    'Esc with focus outside closes nothing',
    (tester) async {
      _view(tester);
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(_button('go', (c) => c.showToast(message: 'Esc me'))),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      // With focus outside every notice, Esc closes nothing (e04).
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(find.text('Esc me'), findsOneWidget);
      // Focus the close button directly, through its semantics focus
      // action rather than a tap (a tap on it closes the notice before
      // any key could reach it), then Esc closes it.
      _focusViaSemantics(tester, 'Close');
      await tester.pump();
      expect(find.text('Esc me'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('Esc me'), findsNothing);
      handle.dispose();
    },
  );

  testWidgets(
    'probe-tab defect 3: focus returns to the node that held it before it '
    'entered the notice, not the route scope, once Esc closes it',
    (tester) async {
      _view(tester);
      final handle = tester.ensureSemantics();
      final field = FocusNode(debugLabel: 'field');
      addTearDown(field.dispose);
      await tester.pumpWidget(
        _app(
          Column(
            children: [
              Focus(
                focusNode: field,
                child: const SizedBox.square(dimension: 1),
              ),
              _button(
                'go',
                (c) => c.showToast(message: 'Tab close', action: undo),
              ),
            ],
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      field.requestFocus();
      await tester.pump();
      expect(FocusManager.instance.primaryFocus, field);
      // Real Tab presses off the web with a plain Navigator reach the
      // notice after the route's last control (probe-tab findings, table
      // rows 1-2); the route's own traversal edge unfocuses whatever held
      // focus on the way in, which is the defect's root cause, so this
      // must be a real key press, never a semantics focus-action
      // shortcut. `field` is not necessarily that node: the route may
      // hold other controls (here, "go") Tab visits first, so the node
      // to expect back is whatever this loop last saw before the press
      // that lands inside the notice, not `field` itself.
      FocusNode? before;
      var reached = false;
      for (var i = 0; i < 6 && !reached; i++) {
        before = FocusManager.instance.primaryFocus;
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        reached =
            tester
                .getSemantics(find.bySemanticsLabel('Undo'))
                .flagsCollection
                .isFocused ==
            Tristate.isTrue;
      }
      expect(
        reached,
        isTrue,
        reason: 'Tab never reached the notice within 6 presses',
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('Tab close'), findsNothing);
      // Never the route scope itself (where Tab's `parentScope` edge
      // would otherwise park it): focus is back on whatever held it
      // immediately before the notice.
      expect(FocusManager.instance.primaryFocus, before);
      handle.dispose();
    },
  );

  testWidgets(
    'us01/s9: NFR-U06: us01/fr05: announced as kind name then message, '
    'focus kept',
    (tester) async {
      _view(tester);
      final announced = _announceRecorder(tester);
      await tester.pumpWidget(
        _app(
          _button(
            'go',
            (c) => c.showToast(
              message: 'Low battery',
              kind: FeedbackState.warning,
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      final focusBefore = FocusManager.instance.primaryFocus;
      await tester.pumpAndSettle();
      expect(announced, ['Warning, Low battery']);
      expect(FocusManager.instance.primaryFocus, focusBefore);
    },
  );

  testWidgets('us01/s10: us01/fr05/e01: announced in Thai', (tester) async {
    _view(tester);
    final announced = _announceRecorder(tester);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('th'),
        supportedLocales: const [Locale('en'), Locale('th')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        builder: (context, child) => StratumThemeApplication(
          themes: StratumThemeSet(light: fakeTheme),
          themeMode: ThemeMode.light,
          child: StratumToastHost(child: child!),
        ),
        home: Scaffold(
          body: _button(
            'go',
            (c) => c.showToast(
              message: 'บันทึกไม่สำเร็จ',
              kind: FeedbackState.negative,
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(announced, ['ข้อผิดพลาด, บันทึกไม่สำเร็จ']);
  });

  testWidgets('us01/fr05/e03: a queued solid notice is announced only when '
      'it shows', (tester) async {
    _view(tester);
    final announced = _announceRecorder(tester);
    await tester.pumpWidget(
      _app(
        _button('go', (c) {
          c
            ..showToast(
              message: 'one',
              placement: const StratumToastPlacement.solid(
                StratumToastEdge.bottom,
              ),
            )
            ..showToast(
              message: 'two',
              placement: const StratumToastPlacement.solid(
                StratumToastEdge.bottom,
              ),
            );
        }),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(announced, ['Information, one']);
  });

  testWidgets(
    'NFR-U06: us01/fr01/e08: the kind icon, the action, and the close '
    'button each carry their own accessible name',
    (tester) async {
      _view(tester);
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(
          _button(
            'go',
            (c) => c.showToast(
              message: 'Low battery',
              kind: FeedbackState.warning,
              action: undo,
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      // The kind icon's own node: FO-09 FR-01 E08 names the kind as the
      // source of both the announcement and the icon's accessible name.
      expect(
        tester.getSemantics(find.bySemanticsLabel('Warning')),
        matchesSemantics(label: 'Warning'),
      );
      for (final label in ['Undo', 'Close']) {
        expect(
          tester.getSemantics(find.bySemanticsLabel(label)),
          matchesSemantics(
            label: label,
            isButton: true,
            hasEnabledState: true,
            isEnabled: true,
            isFocusable: true,
            hasTapAction: true,
            hasFocusAction: true,
          ),
          reason: label,
        );
      }
      handle.dispose();
    },
  );

  testWidgets(
    'us01/s21: us01/fr06/e04: an app builder draws the look, the host '
    'keeps timing',
    (tester) async {
      _view(tester);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => StratumThemeApplication(
            themes: StratumThemeSet(light: fakeTheme),
            themeMode: ThemeMode.light,
            child: StratumToastHost(
              builder: (context, notice) => Text('mine: ${notice.message}'),
              child: child!,
            ),
          ),
          home: Scaffold(body: _button('go', (c) => c.showToast(message: 'x'))),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      expect(find.text('mine: x'), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(find.text('mine: x'), findsNothing);
    },
  );

  testWidgets('NFR-U08: us01/s20: us01/fr06/e03: each of the four kinds '
      'shows its own icon under high contrast', (tester) async {
    _view(tester);
    final icons = <IconData?>{};
    for (final kind in FeedbackState.values) {
      await tester.pumpWidget(
        _app(
          _button('go', (c) => c.showToast(message: kind.name, kind: kind)),
          highContrast: StratumHighContrastMode.on,
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      icons.addAll(
        tester.widgetList<Icon>(find.byType(Icon)).map((i) => i.icon),
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    }
    expect(icons.length, greaterThanOrEqualTo(5)); // four kinds plus close
  });

  testWidgets(
    'NFR-U04: us01/s19: us01/fr06/e02: at 200% the message wraps with no '
    'overflow',
    (tester) async {
      _view(tester);
      await tester.pumpWidget(
        _app(
          _button(
            'go',
            (c) => c.showToast(
              message: 'A message long enough to wrap onto two lines',
            ),
          ),
          media: (data) =>
              data.copyWith(textScaler: const TextScaler.linear(2)),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  for (final (source, app, platform) in [
    ('app', true, false),
    ('platform', false, true),
  ]) {
    testWidgets(
      'NFR-U03: us01/s18: under $source reduced motion one pump shows the '
      'settled look',
      (tester) async {
        _view(tester);
        if (platform) {
          tester.platformDispatcher.accessibilityFeaturesTestValue =
              const FakeAccessibilityFeatures(reduceMotion: true);
          addTearDown(
            tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
          );
        }
        Widget host() => _app(
          _button('go', (c) => c.showToast(message: 'Fade')),
          media: (data) => data.copyWith(disableAnimations: app),
        );
        await tester.pumpWidget(host());
        await tester.tap(find.text('go'));
        // The overlay entry lands after toastification's post-frame add,
        // so pump timed frames until the notice paints, then one more:
        // under reduced motion the look must already sit at its settled
        // geometry (opacity may still fade).
        var frames = 0;
        while (find.text('Fade').evaluate().isEmpty && frames < 10) {
          await tester.pump(const Duration(milliseconds: 16));
          frames++;
        }
        await tester.pump(const Duration(milliseconds: 16));
        final first = tester.getRect(find.text('Fade'));
        await tester.pumpAndSettle();
        expect(tester.getRect(find.text('Fade')), first);
      },
    );
  }

  testWidgets(
    'NFR-U03: us01/s18: with full motion the show still runs, proving the '
    'reduced rows are not vacuous',
    (tester) async {
      _view(tester);
      await tester.pumpWidget(
        _app(_button('go', (c) => c.showToast(message: 'Slide'))),
      );
      await tester.tap(find.text('go'));
      var frames = 0;
      while (find.text('Slide').evaluate().isEmpty && frames < 10) {
        await tester.pump(const Duration(milliseconds: 16));
        frames++;
      }
      await tester.pump(const Duration(milliseconds: 16));
      final during = tester.getRect(find.text('Slide'));
      await tester.pumpAndSettle();
      expect(tester.getRect(find.text('Slide')), isNot(during));
    },
  );

  testWidgets(
    'NFR-U01: NFR-U05: NFR-U07: action and close are labeled, sized, and '
    'readable',
    (tester) async {
      _view(tester);
      final handle = tester.ensureSemantics();
      for (final theme in [defaultThemeSet.light, defaultThemeSet.dark!]) {
        // FR-06 E05 names every kind, not only `info`: a border or icon
        // color regression in `_kindBorder`/`_kindIcon` for one kind must
        // fail here too.
        for (final kind in FeedbackState.values) {
          Widget app() => MaterialApp(
            builder: (context, child) => StratumThemeApplication(
              themes: StratumThemeSet(light: theme),
              themeMode: ThemeMode.light,
              child: StratumToastHost(child: child!),
            ),
            home: Scaffold(
              body: _button(
                'go',
                (c) => c.showToast(
                  message: 'Item deleted',
                  action: undo,
                  kind: kind,
                ),
              ),
            ),
          );
          await tester.pumpWidget(app());
          await tester.tap(find.text('go'));
          await tester.pumpAndSettle();
          // Drop the page's blue Material button, keeping the host and
          // its notice, so the guidelines read the notice alone.
          await tester.pumpWidget(
            MaterialApp(
              builder: (context, child) => StratumThemeApplication(
                themes: StratumThemeSet(light: theme),
                themeMode: ThemeMode.light,
                child: StratumToastHost(child: child!),
              ),
              home: const Scaffold(body: SizedBox()),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text('Item deleted'), findsOneWidget);
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
          await expectLater(tester, meetsGuideline(textContrastGuideline));
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
        }
      }
      handle.dispose();
    },
  );

  testWidgets(
    'NFR-U02: us01/fr05/e04: Tab reaches the action, then the close button',
    (tester) async {
      _view(tester);
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(_button('go', (c) => c.showToast(message: 'Tab', action: undo))),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      // Focus the action directly (a tap on it would close the notice
      // first), then Tab from it reaches the close button next, both
      // inside the notice's focus ring (N18).
      // A semantics focus action is a touch-style interaction, so force
      // the traditional highlight mode: the gate's ring is for keyboard
      // focus, not a touch tap (correct behavior; this test proves Tab
      // order, which needs focus already placed in the notice).
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTraditional;
      addTearDown(
        () => FocusManager.instance.highlightStrategy =
            FocusHighlightStrategy.automatic,
      );
      _focusViaSemantics(tester, 'Undo');
      await tester.pumpAndSettle();
      _expectFocusedInRing(tester, find.text('Undo'));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Close'), findsOneWidget);
      _expectFocusedInRing(tester, find.byIcon(Icons.close));
      handle.dispose();
    },
  );

  testWidgets('NFR-U09: us01/s13: us01/fr04/e05: the close button (the swipe '
      "gesture's tap alternative) closes it", (tester) async {
    _view(tester);
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _app(_button('go', (c) => c.showToast(message: 'Swipe'))),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(
      tester.getSemantics(find.bySemanticsLabel('Close')),
      matchesSemantics(
        label: 'Close',
        isButton: true,
        hasEnabledState: true,
        isEnabled: true,
        isFocusable: true,
        hasTapAction: true,
        hasFocusAction: true,
      ),
    );
    await tester.tap(find.bySemanticsLabel('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Swipe'), findsNothing);
    handle.dispose();
  });

  testWidgets(
    'NFR-E01: us01/fr06/e01: review focus 5: the look follows the theme '
    'while the notice shows',
    (tester) async {
      _view(tester);
      Widget app(StratumThemeData theme) => MaterialApp(
        builder: (context, child) => StratumThemeApplication(
          themes: StratumThemeSet(light: theme),
          themeMode: ThemeMode.light,
          child: StratumToastHost(child: child!),
        ),
        home: Scaffold(body: _button('go', (c) => c.showToast(message: 'T'))),
      );
      await tester.pumpWidget(app(defaultThemeSet.light));
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      final light = _surfaceColor(tester, 'T');
      // Switch the theme while the same notice shows (N18): the notice
      // still on screen repaints on the dark tokens.
      await tester.pumpWidget(app(defaultThemeSet.dark!));
      await tester.pumpAndSettle();
      final dark = _surfaceColor(tester, 'T');
      expect(find.text('T'), findsOneWidget);
      expect(light, isNot(dark));
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );

  testWidgets('NFR-E02: a call customStyle wins over the theme, field by '
      'field', (tester) async {
    _view(tester);
    const red = Color(0xFFFF0000);
    await tester.pumpWidget(
      _app(
        _button(
          'go',
          (c) => c.showToast(
            message: 'S',
            customStyle: const WidgetStyle(backgroundColor: red),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    final style = tester.widget<ContainerLayout>(_fill('S')).style!;
    expect(style.backgroundColor, red);
    expect(style.dropShadow, isNotEmpty);
  });

  testWidgets('us01/fr06: s03 invariant 16: the app-wide '
      'StratumComponentDefaults.partsOf<WidgetStyle> layer wins over the '
      'theme, with no customStyle set', (tester) async {
    _view(tester);
    const green = Color(0xFF00FF00);
    await tester.pumpWidget(
      _app(
        _button('go', (c) => c.showToast(message: 'P')),
        componentPartDefaults: (theme) => {
          StratumToastHost: const WidgetStyle(backgroundColor: green),
        },
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    final style = tester.widget<ContainerLayout>(_fill('P')).style!;
    expect(style.backgroundColor, green);
  });

  testWidgets(
    'n20: us01/fr06/e06: StratumToastHost(closeButtonLabel:, kindLabels:) '
    "override FO-09's built-in labels (s03 invariant 11)",
    (tester) async {
      _view(tester);
      final handle = tester.ensureSemantics();
      final announced = _announceRecorder(tester);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => StratumThemeApplication(
            themes: StratumThemeSet(light: fakeTheme),
            themeMode: ThemeMode.light,
            child: StratumToastHost(
              closeButtonLabel: 'Dismiss',
              kindLabels: const {FeedbackState.info: 'FYI'},
              child: child!,
            ),
          ),
          home: Scaffold(body: _button('go', (c) => c.showToast(message: 'x'))),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      expect(announced, ['FYI, x']);
      expect(
        tester.getSemantics(find.bySemanticsLabel('FYI')),
        matchesSemantics(label: 'FYI'),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('Dismiss')),
        matchesSemantics(
          label: 'Dismiss',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          isFocusable: true,
          hasTapAction: true,
          hasFocusAction: true,
        ),
      );
      handle.dispose();
    },
  );

  testWidgets(
    'us01/fr05/e02: an unheld locale (Japanese) reads the English kind '
    'name',
    (tester) async {
      _view(tester);
      final announced = _announceRecorder(tester);
      await tester.pumpWidget(
        _app(
          _button('go', (c) => c.showToast(message: 'x')),
          locale: const Locale('ja'),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      expect(announced, ['Information, x']);
    },
  );

  testWidgets(
    'us01/fr02/e08: a dark solid top notice over a light header flips the '
    'status bar icons',
    (tester) async {
      systemBarsView(tester);
      await tester.pumpWidget(
        _systemApp(
          goStyle: const WidgetStyle(backgroundColor: Color(0xFF1F242E)),
        ),
      );
      // A light page header: dark icons win on it.
      expect(
        SystemChrome.latestStyle?.statusBarIconBrightness,
        Brightness.dark,
      );
      // A dark solid top notice covers the bar point: light icons win on
      // its declared fill while it shows (piece 5).
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      expect(
        SystemChrome.latestStyle?.statusBarIconBrightness,
        Brightness.light,
      );
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      // The notice gone, the header's fill wins again.
      expect(
        SystemChrome.latestStyle?.statusBarIconBrightness,
        Brightness.dark,
      );
    },
  );

  testWidgets(
    'us01/fr02/e08: a dark solid bottom notice over a light footer flips '
    'the navigation bar icons',
    (tester) async {
      systemBarsView(tester);
      // T27 lifts a solid bottom notice above a page footer, so this row
      // runs on a page without one: the fill runs under the home
      // indicator and covers the bar point (FR-02 statement).
      await tester.pumpWidget(
        _systemApp(
          edge: StratumToastEdge.bottom,
          pageBars: false,
          goStyle: const WidgetStyle(backgroundColor: Color(0xFF1F242E)),
        ),
      );
      // No page fill under the bar: dark icons win on the plain page.
      expect(
        SystemChrome.latestStyle?.systemNavigationBarIconBrightness,
        Brightness.dark,
      );
      // A dark solid bottom notice covers the bar point: light icons win
      // on its declared fill while it shows (piece 5, both edges).
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      expect(
        SystemChrome.latestStyle?.systemNavigationBarIconBrightness,
        Brightness.light,
      );
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      // The notice gone, the page's own fill wins again.
      expect(
        SystemChrome.latestStyle?.systemNavigationBarIconBrightness,
        Brightness.dark,
      );
    },
  );

  testWidgets(
    'us01/fr02/e09: a gradient fill and an app look declare nothing',
    (tester) async {
      systemBarsView(tester);
      await tester.pumpWidget(
        _systemApp(
          builder: (context, notice) => Text('app: ${notice.message}'),
        ),
      );
      expect(
        SystemChrome.latestStyle?.statusBarIconBrightness,
        Brightness.dark,
      );
      // A gradient customStyle declares nothing, so the header's white fill
      // still wins the bar point.
      await tester.tap(find.text('gradient'));
      await tester.pumpAndSettle();
      expect(
        SystemChrome.latestStyle?.statusBarIconBrightness,
        Brightness.dark,
      );
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      // An app builder look declares nothing either.
      await tester.tap(find.text('mine'));
      await tester.pumpAndSettle();
      expect(find.text('app: Mine'), findsOneWidget);
      expect(
        SystemChrome.latestStyle?.statusBarIconBrightness,
        Brightness.dark,
      );
    },
  );

  testWidgets(
    "n17: the message reads the theme body style, not toastification's "
    'Material default',
    (tester) async {
      _view(tester);
      final dark = defaultThemeSet.dark!;
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => StratumThemeApplication(
            themes: StratumThemeSet(light: dark),
            themeMode: ThemeMode.light,
            child: StratumToastHost(child: child!),
          ),
          home: Scaffold(body: _button('go', (c) => c.showToast(message: 'D'))),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      final message = tester.widget<Text>(find.text('D'));
      // The dark theme's primary text color, never Material light's black.
      expect(message.style?.color, dark.color.text.defaults.primary);
    },
  );

  // R27: the host shortcut and its hint (US-01 FR-05 statement, E05 to
  // E14; FR-06 E06; s03 invariants 10, 11, 18, 19).

  testWidgets(
    'us01/fr05/e06 e10: the default shortcut reaches the notice from a '
    'text field on the web-edge route, and Esc returns focus with its '
    'text intact',
    (tester) async {
      _view(tester);
      await _withTargetPlatform(TargetPlatform.linux, () async {
        final handle = tester.ensureSemantics();
        final field = FocusNode(debugLabel: 'field');
        addTearDown(field.dispose);
        await tester.pumpWidget(
          _webEdgeApp(
            Column(
              children: [
                TextField(focusNode: field),
                _button(
                  'go',
                  (c) => c.showToast(message: 'Hint', action: undo),
                ),
              ],
            ),
          ),
        );
        await tester.tap(find.text('go'));
        await tester.pumpAndSettle();
        field.requestFocus();
        await tester.pump();
        await tester.enterText(find.byType(TextField), 'hi');
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.f8);
        await tester.pumpAndSettle();
        _expectFocusedInRing(tester, find.text('Undo'));
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(find.text('Hint'), findsNothing);
        expect(FocusManager.instance.primaryFocus, field);
        expect(
          tester
              .state<EditableTextState>(find.byType(EditableText))
              .textEditingValue
              .text,
          'hi',
        );
        handle.dispose();
      });
    },
  );

  testWidgets(
    'us01/fr05/e07: the shortcut reaches the notice from inside an open '
    "dialog, and closing it returns focus to the dialog's control",
    (tester) async {
      _view(tester);
      await _withTargetPlatform(TargetPlatform.linux, () async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          _app(_button('go', (c) => c.showToast(message: 'Dlg', action: undo))),
        );
        await tester.tap(find.text('go'));
        await tester.pumpAndSettle();
        final ctx = tester.element(find.text('go'));
        unawaited(
          showDialog<void>(
            context: ctx,
            builder: (_) => AlertDialog(
              content: TextButton(onPressed: () {}, child: const Text('OK')),
            ),
          ),
        );
        await tester.pumpAndSettle();
        _focusViaSemantics(tester, 'OK');
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.f8);
        await tester.pumpAndSettle();
        _expectFocusedInRing(tester, find.text('Undo'));
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(find.text('Dlg'), findsNothing);
        expect(find.bySemanticsLabel('OK'), findsOneWidget);
        handle.dispose();
      });
    },
  );

  testWidgets('us01/fr05/e08: the shortcut does nothing while no notice '
      'shows', (tester) async {
    _view(tester);
    await _withTargetPlatform(TargetPlatform.linux, () async {
      final field = FocusNode(debugLabel: 'field');
      addTearDown(field.dispose);
      await tester.pumpWidget(
        _app(Focus(focusNode: field, child: const SizedBox())),
      );
      field.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.f8);
      await tester.pump();
      expect(FocusManager.instance.primaryFocus, field);
    });
  });

  testWidgets(
    'us01/fr05/e11: an empty focusShortcuts list binds no key and the '
    'announcement carries no hint',
    (tester) async {
      _view(tester);
      await _withTargetPlatform(TargetPlatform.linux, () async {
        final announced = _announceRecorder(tester);
        final field = FocusNode(debugLabel: 'field');
        addTearDown(field.dispose);
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => StratumThemeApplication(
              themes: StratumThemeSet(light: fakeTheme),
              themeMode: ThemeMode.light,
              child: StratumToastHost(focusShortcuts: const [], child: child!),
            ),
            home: Scaffold(
              body: Column(
                children: [
                  Focus(focusNode: field, child: const SizedBox()),
                  _button('go', (c) => c.showToast(message: 'x', action: undo)),
                ],
              ),
            ),
          ),
        );
        await tester.tap(find.text('go'));
        await tester.pumpAndSettle();
        expect(announced, ['Information, x']);
        field.requestFocus();
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.f8);
        await tester.pump();
        expect(FocusManager.instance.primaryFocus, field);
      });
    },
  );

  testWidgets(
    'us01/fr05/e13: on macOS the default shortcut is Option+T then F8, '
    'the hint naming Option+T first',
    (tester) async {
      _view(tester);
      await _withTargetPlatform(TargetPlatform.macOS, () async {
        final announced = _announceRecorder(tester);
        await tester.pumpWidget(
          _app(_button('go', (c) => c.showToast(message: 'x', action: undo))),
        );
        await tester.tap(find.text('go'));
        await tester.pumpAndSettle();
        expect(announced, ['Information, x, Press Option+T to reach it']);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyT);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
        await tester.pumpAndSettle();
        _expectFocusedInRing(tester, find.text('Undo'));
      });
    },
  );

  testWidgets(
    'us01/fr05/e13: elsewhere the default shortcut is F8 then Alt+T, the '
    'hint naming F8 first',
    (tester) async {
      _view(tester);
      await _withTargetPlatform(TargetPlatform.linux, () async {
        final announced = _announceRecorder(tester);
        await tester.pumpWidget(
          _app(_button('go', (c) => c.showToast(message: 'x', action: undo))),
        );
        await tester.tap(find.text('go'));
        await tester.pumpAndSettle();
        expect(announced, ['Information, x, Press F8 to reach it']);
        await tester.sendKeyEvent(LogicalKeyboardKey.f8);
        await tester.pumpAndSettle();
        _expectFocusedInRing(tester, find.text('Undo'));
      });
    },
  );

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('us01/fr05/e14: no hint on $platform', (tester) async {
      _view(tester);
      await _withTargetPlatform(platform, () async {
        final announced = _announceRecorder(tester);
        await tester.pumpWidget(
          _app(_button('go', (c) => c.showToast(message: 'x'))),
        );
        await tester.tap(find.text('go'));
        await tester.pumpAndSettle();
        expect(announced, ['Information, x']);
      });
    });
  }

  testWidgets('us01/fr06/e06: focusShortcutHint: replaces the built-in hint', (
    tester,
  ) async {
    _view(tester);
    await _withTargetPlatform(TargetPlatform.linux, () async {
      final announced = _announceRecorder(tester);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => StratumThemeApplication(
            themes: StratumThemeSet(light: fakeTheme),
            themeMode: ThemeMode.light,
            child: StratumToastHost(
              focusShortcutHint: 'or hit F8',
              child: child!,
            ),
          ),
          home: Scaffold(body: _button('go', (c) => c.showToast(message: 'x'))),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      expect(announced, ['Information, x, or hit F8']);
    });
  });

  testWidgets('us01/fr05/e01: the Thai hint names the key', (tester) async {
    _view(tester);
    await _withTargetPlatform(TargetPlatform.linux, () async {
      final announced = _announceRecorder(tester);
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('th'),
          supportedLocales: const [Locale('en'), Locale('th')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          builder: (context, child) => StratumThemeApplication(
            themes: StratumThemeSet(light: fakeTheme),
            themeMode: ThemeMode.light,
            child: StratumToastHost(child: child!),
          ),
          home: Scaffold(body: _button('go', (c) => c.showToast(message: 'x'))),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      expect(announced, ['ข้อมูล, x, กด F8 เพื่อไปที่การแจ้งเตือนนี้']);
    });
  });

  // R27 fix round 1: review-r27.correctness.review.md finding 1,
  // review-r27.edge.review.md findings B to E and G.

  testWidgets(
    'us01/fr05/fr06/e04: the shortcut reaches a custom builder look, its '
    'first traversable descendant, no plain-look focus-node plumbing '
    'needed',
    (tester) async {
      _view(tester);
      final handle = tester.ensureSemantics();
      await _withTargetPlatform(TargetPlatform.linux, () async {
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => StratumThemeApplication(
              themes: StratumThemeSet(light: fakeTheme),
              themeMode: ThemeMode.light,
              child: StratumToastHost(
                builder: (context, notice) => TextButton(
                  onPressed: notice.close,
                  child: Text('mine: ${notice.message}'),
                ),
                child: child!,
              ),
            ),
            home: Scaffold(
              body: _button('go', (c) => c.showToast(message: 'x')),
            ),
          ),
        );
        await tester.tap(find.text('go'));
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.f8);
        await tester.pumpAndSettle();
        expect(
          tester
              .getSemantics(find.bySemanticsLabel('mine: x'))
              .flagsCollection
              .isFocused,
          Tristate.isTrue,
        );
      });
      handle.dispose();
    },
  );

  testWidgets('us01/fr05: a notice with no focusable descendant leaves the key '
      'unhandled', (tester) async {
    _view(tester);
    await _withTargetPlatform(TargetPlatform.linux, () async {
      final field = FocusNode(debugLabel: 'field');
      addTearDown(field.dispose);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => StratumThemeApplication(
            themes: StratumThemeSet(light: fakeTheme),
            themeMode: ThemeMode.light,
            child: StratumToastHost(
              builder: (context, notice) => Text(notice.message),
              child: child!,
            ),
          ),
          home: Scaffold(
            body: Column(
              children: [
                Focus(focusNode: field, child: const SizedBox()),
                _button('go', (c) => c.showToast(message: 'x')),
              ],
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      field.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.f8);
      await tester.pump();
      expect(FocusManager.instance.primaryFocus, field);
    });
  });

  testWidgets('us01/fr05: the shortcut reaches a close-only notice through its '
      'close button', (tester) async {
    _view(tester);
    await _withTargetPlatform(TargetPlatform.linux, () async {
      await tester.pumpWidget(
        _app(_button('go', (c) => c.showToast(message: 'x'))),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.f8);
      await tester.pumpAndSettle();
      _expectFocusedInRing(tester, find.byIcon(Icons.close));
    });
  });

  testWidgets(
    'us01/fr05/e09: with several notices on screen, the shortcut reaches '
    'the one that showed last',
    (tester) async {
      _view(tester);
      final handle = tester.ensureSemantics();
      await _withTargetPlatform(TargetPlatform.linux, () async {
        await tester.pumpWidget(
          _app(
            _button('go', (c) {
              c
                ..showToast(
                  message: 'First',
                  action: const StratumToastAction(
                    label: 'A',
                    onPressed: _noop,
                  ),
                )
                ..showToast(
                  message: 'Second',
                  action: const StratumToastAction(
                    label: 'B',
                    onPressed: _noop,
                  ),
                );
            }),
          ),
        );
        await tester.tap(find.text('go'));
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.f8);
        await tester.pumpAndSettle();
        _expectFocusedInRing(tester, find.text('B'));
        expect(
          tester
              .getSemantics(find.bySemanticsLabel('A'))
              .flagsCollection
              .isFocused,
          isNot(Tristate.isTrue),
        );
      });
      handle.dispose();
    },
  );

  testWidgets(
    'us01/fr05/e10: a custom non-empty focusShortcuts list moves focus; '
    'the default key no longer does, and the hint names the custom key',
    (tester) async {
      _view(tester);
      const custom = SingleActivator(LogicalKeyboardKey.keyR, control: true);
      await _withTargetPlatform(TargetPlatform.linux, () async {
        final announced = _announceRecorder(tester);
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => StratumThemeApplication(
              themes: StratumThemeSet(light: fakeTheme),
              themeMode: ThemeMode.light,
              child: StratumToastHost(
                focusShortcuts: const [custom],
                child: child!,
              ),
            ),
            home: Scaffold(
              body: _button(
                'go',
                (c) => c.showToast(message: 'x', action: undo),
              ),
            ),
          ),
        );
        await tester.tap(find.text('go'));
        await tester.pumpAndSettle();
        expect(announced, ['Information, x, Press Ctrl+R to reach it']);
        final handle = tester.ensureSemantics();
        // The platform default no longer binds.
        await tester.sendKeyEvent(LogicalKeyboardKey.f8);
        await tester.pump();
        expect(
          tester
              .getSemantics(find.bySemanticsLabel('Undo'))
              .flagsCollection
              .isFocused,
          isNot(Tristate.isTrue),
        );
        // The app's own key does.
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pumpAndSettle();
        _expectFocusedInRing(tester, find.text('Undo'));
        handle.dispose();
      });
    },
  );

  testWidgets('Minor G: popping a route while focus sits in a notice via the '
      'shortcut crashes nothing, and the notice is still reachable and '
      'closeable after', (tester) async {
    _view(tester);
    final handle = tester.ensureSemantics();
    await _withTargetPlatform(TargetPlatform.linux, () async {
      await tester.pumpWidget(
        _app(_button('go', (c) => c.showToast(message: 'Pop', action: undo))),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      final ctx = tester.element(find.text('go'));
      Navigator.of(ctx).push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: SizedBox()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.f8);
      await tester.pumpAndSettle();
      _expectFocusedInRing(tester, find.text('Undo'));
      // The pop may move focus off the notice's own pre-entry node (a
      // route's own focus-restore is Flutter's, not this fix's, to
      // prove); only that nothing crashes is asserted here.
      Navigator.of(ctx).pop();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      // The notice is still there, and the shortcut still reaches it.
      await tester.sendKeyEvent(LogicalKeyboardKey.f8);
      await tester.pumpAndSettle();
      _expectFocusedInRing(tester, find.text('Undo'));
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('Pop'), findsNothing);
      expect(tester.takeException(), isNull);
    });
    handle.dispose();
  });

  // Final fix wave A: review-final-m4 edge I1, I4, I9; correctness 8, 9, 10.

  testWidgets(
    'us01/fr04/e03: edge I1: a later notice at the same corner leaves the '
    'first one focused, paused, and reachable by the shortcut',
    (tester) async {
      _view(tester);
      final handle = tester.ensureSemantics();
      await _withTargetPlatform(TargetPlatform.linux, () async {
        final field = FocusNode(debugLabel: 'field');
        addTearDown(field.dispose);
        late BuildContext ctx;
        await tester.pumpWidget(
          _app(
            Column(
              children: [
                Focus(
                  focusNode: field,
                  child: const SizedBox.square(dimension: 1),
                ),
                Builder(
                  builder: (c) {
                    ctx = c;
                    return const SizedBox();
                  },
                ),
              ],
            ),
          ),
        );
        ctx.showToast(
          message: 'First',
          action: const StratumToastAction(label: 'A', onPressed: _noop),
        );
        await tester.pumpAndSettle();
        field.requestFocus();
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.f8);
        await tester.pumpAndSettle();
        _expectFocusedInRing(tester, find.text('A'));
        // toastification inserts the later notice at index 0 of the same
        // corner's list, which shifts the first notice's slot.
        ctx.showToast(message: 'Second');
        await tester.pumpAndSettle();
        expect(find.text('Second'), findsOneWidget);
        _expectFocusedInRing(tester, find.text('A'));
        // Focus inside holds the first notice past both close times.
        await tester.pump(const Duration(seconds: 9));
        await tester.pumpAndSettle();
        expect(find.text('Second'), findsNothing);
        expect(find.text('First'), findsOneWidget);
        // The shortcut still reaches it once focus has left it.
        field.requestFocus();
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.f8);
        await tester.pumpAndSettle();
        _expectFocusedInRing(tester, find.text('A'));
        // Its timer resumes with the remaining time once focus leaves.
        field.requestFocus();
        await tester.pump(const Duration(seconds: 8));
        await tester.pumpAndSettle();
        expect(find.text('First'), findsNothing);
      });
      handle.dispose();
    },
  );

  testWidgets(
    'us01/fr03/e04: us01/fr04/e07: correctness 8, edge I4: evicting the '
    'focused oldest notice returns focus as a close does',
    (tester) async {
      _view(tester);
      final handle = tester.ensureSemantics();
      final field = FocusNode(debugLabel: 'field');
      addTearDown(field.dispose);
      await tester.pumpWidget(
        _app(
          Column(
            children: [
              Focus(
                focusNode: field,
                child: const SizedBox.square(dimension: 1),
              ),
              _button('go', (c) {
                for (final label in ['A', 'B', 'C']) {
                  c.showToast(
                    message: 'n$label',
                    action: StratumToastAction(label: label, onPressed: _noop),
                  );
                }
              }),
            ],
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      field.requestFocus();
      await tester.pump();
      // Real Tab presses, as in probe-tab defect 3: the route's traversal
      // edge drops its own focus history on the way into a notice, so only
      // the host's kept node can bring focus back.
      FocusNode? before;
      var reached = false;
      for (var i = 0; i < 6 && !reached; i++) {
        before = FocusManager.instance.primaryFocus;
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        reached =
            tester
                .getSemantics(find.bySemanticsLabel('A'))
                .flagsCollection
                .isFocused ==
            Tristate.isTrue;
      }
      expect(reached, isTrue, reason: 'Tab never reached the oldest notice');
      tester.element(find.text('go')).showToast(message: 'nD');
      await tester.pumpAndSettle();
      expect(find.text('nA'), findsNothing);
      expect(find.text('nD'), findsOneWidget);
      expect(FocusManager.instance.primaryFocus, before);
      handle.dispose();
    },
  );

  testWidgets(
    'us01/fr04/e09: its page closed while focus sat in the notice, focus '
    'goes to the page now on top',
    (tester) async {
      _view(tester);
      final handle = tester.ensureSemantics();
      await _withTargetPlatform(TargetPlatform.linux, () async {
        final field = FocusNode(debugLabel: 'field');
        addTearDown(field.dispose);
        await tester.pumpWidget(
          _app(
            _button('go', (c) => c.showToast(message: 'Gone', action: undo)),
          ),
        );
        await tester.tap(find.text('go'));
        await tester.pumpAndSettle();
        final home = tester.element(find.text('go'));
        Navigator.of(home).push(
          MaterialPageRoute<void>(
            builder: (_) => Scaffold(
              body: Focus(
                focusNode: field,
                child: const SizedBox.square(dimension: 1),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        field.requestFocus();
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.f8);
        await tester.pumpAndSettle();
        _expectFocusedInRing(tester, find.text('Undo'));
        Navigator.of(home).pop();
        await tester.pumpAndSettle();
        // The route now on top takes focus as it becomes current
        // (`ModalRoute` `setFirstFocus`), so the notice holds none.
        expect(field.parent, isNull, reason: 'its page closed');
        _expectFocusInside(FocusScope.of(home));
        expect(find.text('Gone'), findsOneWidget);
      });
      handle.dispose();
    },
  );

  testWidgets(
    'us01/fr04/e09: correctness 9, edge I4: with the control that held '
    'focus gone, a close focuses the page on top, and the control coming '
    'back takes no focus',
    (tester) async {
      _view(tester);
      final handle = tester.ensureSemantics();
      await _withTargetPlatform(TargetPlatform.linux, () async {
        final field = FocusNode(debugLabel: 'field');
        addTearDown(field.dispose);
        final fieldShown = ValueNotifier(true);
        addTearDown(fieldShown.dispose);
        await tester.pumpWidget(
          _app(
            Column(
              children: [
                ValueListenableBuilder(
                  valueListenable: fieldShown,
                  builder: (_, shown, _) => shown
                      ? Focus(
                          focusNode: field,
                          child: const SizedBox.square(dimension: 1),
                        )
                      : const SizedBox(),
                ),
                _button(
                  'go',
                  (c) => c.showToast(message: 'Gone', action: undo),
                ),
              ],
            ),
          ),
        );
        await tester.tap(find.text('go'));
        await tester.pumpAndSettle();
        field.requestFocus();
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.f8);
        await tester.pumpAndSettle();
        _expectFocusedInRing(tester, find.text('Undo'));
        fieldShown.value = false;
        await tester.pump();
        expect(field.parent, isNull, reason: 'the control is gone');
        _expectFocusedInRing(tester, find.text('Undo'));
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(find.text('Gone'), findsNothing);
        final pageScope = FocusScope.of(tester.element(find.text('go')));
        _expectFocusInside(pageScope);
        // A detached node asked for focus would take it on its return.
        fieldShown.value = true;
        await tester.pumpAndSettle();
        expect(FocusManager.instance.primaryFocus, isNot(field));
        _expectFocusInside(pageScope);
      });
      handle.dispose();
    },
  );

  testWidgets(
    'NFR-U03: us01/s18: correctness 10: under reduced motion the notice '
    'fades in, with no slide',
    (tester) async {
      _view(tester);
      await tester.pumpWidget(
        _app(
          _button('go', (c) => c.showToast(message: 'Fade')),
          media: (data) => data.copyWith(disableAnimations: true),
        ),
      );
      await tester.tap(find.text('go'));
      var frames = 0;
      while (find.text('Fade').evaluate().isEmpty && frames < 10) {
        await tester.pump(const Duration(milliseconds: 16));
        frames++;
      }
      double opacity() => tester
          .widgetList<FadeTransition>(
            find.ancestor(
              of: find.text('Fade'),
              matching: find.byType(FadeTransition),
            ),
          )
          .fold(1, (product, fade) => product * fade.opacity.value);
      final first = tester.getRect(find.text('Fade'));
      expect(opacity(), lessThan(1));
      await tester.pumpAndSettle();
      expect(opacity(), 1);
      expect(tester.getRect(find.text('Fade')), first);
    },
  );

  testWidgets(
    'NFR-U03: NFR-U09: us01/fr04/e05: edge I9: under reduced motion a swipe '
    'closes the notice at once, with no move or resize animation',
    (tester) async {
      _view(tester);
      await tester.pumpWidget(
        _app(
          _button('go', (c) => c.showToast(message: 'Swipe')),
          media: (data) => data.copyWith(disableAnimations: true),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      await tester.drag(find.text('Swipe'), const Offset(-300, 0));
      await tester.pump();
      await tester.pump();
      expect(find.text('Swipe'), findsNothing);
      expect(tester.takeException(), isNull);
      // Lets toastification's own 50 ms overlay teardown timer run out.
      await tester.pump(const Duration(milliseconds: 50));
    },
  );

  testWidgets(
    'NFR-U09: us01/fr04/e05: edge I9: a fling closes a solid notice, and the '
    'queued one shows',
    (tester) async {
      _view(tester);
      const solid = StratumToastPlacement.solid(StratumToastEdge.bottom);
      await tester.pumpWidget(
        _app(
          _button('go', (c) {
            for (final m in ['one', 'two']) {
              c.showToast(message: m, placement: solid);
            }
          }),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      await tester.fling(find.text('one'), const Offset(-300, 0), 1000);
      await tester.pumpAndSettle();
      expect(find.text('one'), findsNothing);
      expect(find.text('two'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

/// Expects the primary focus on [scope] or one of its descendants.
void _expectFocusInside(FocusScopeNode scope) {
  final primary = FocusManager.instance.primaryFocus;
  expect(
    primary == scope || (primary?.ancestors.contains(scope) ?? false),
    isTrue,
    reason: 'focus sits on $primary, outside $scope',
  );
}

/// The fill color of the notice holding [message].
Color? _surfaceColor(WidgetTester tester, String message) =>
    tester.widget<ContainerLayout>(_fill(message)).style?.backgroundColor;

/// Expects [target], while it holds primary focus, sits inside its
/// `StratumFocusBorder` ring and the ring paints its border, so the
/// focused look differs from the idle alpha 0 (N18).
void _expectFocusedInRing(WidgetTester tester, Finder target) {
  expect(
    find.ancestor(of: target, matching: find.byType(StratumFocusBorder)),
    findsOneWidget,
  );
  final ring = tester.widget<StratumFocusBorder>(
    find.ancestor(of: target, matching: find.byType(StratumFocusBorder)),
  );
  expect(ring.state, FullWidgetState.focused);
  expect(
    tester.renderObject(
      find
          .ancestor(of: target, matching: find.byType(StratumFocusBorder))
          .first,
    ),
    paints..something((method, arguments) {
      if (method != #drawDRRect) return false;
      return arguments.whereType<Paint>().single.color.a > 0;
    }),
  );
}
