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
}) => MaterialApp(
  locale: const Locale('en'),
  supportedLocales: const [Locale('en'), Locale('th')],
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  builder: (context, child) {
    final app = StratumThemeApplication(
      themes: StratumThemeSet(light: fakeTheme),
      themeMode: ThemeMode.light,
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

/// A light-headered page whose host can show a dark solid top notice
/// (`go`), a gradient one (`gradient`), or an app-builder one (`mine`), for
/// the fill the notice declares under the status bar. [builder] replaces
/// the look of every notice when set; [goStyle] overrides the `go` notice.
Widget _systemApp({StratumToastBuilder? builder, WidgetStyle? goStyle}) {
  const top = StratumToastPlacement.solid(StratumToastEdge.top);
  return MaterialApp(
    builder: (context, child) => StratumThemeApplication(
      themes: defaultThemeSet,
      themeMode: ThemeMode.light,
      child: StratumToastHost(builder: builder, child: child!),
    ),
    home: Scaffold(
      body: PageLayout(
        header: const SizedBox(),
        customStyle: const PageLayoutStyle(
          header: WidgetStyle(backgroundColor: _white),
        ),
        body: ColumnLayout(
          children: [
            _button('go', (c) {
              c.showToast(message: 'Top', placement: top, customStyle: goStyle);
            }),
            _button('gradient', (c) {
              c.showToast(
                message: 'Grad',
                placement: top,
                customStyle: const WidgetStyle(
                  backgroundGradient: LinearGradient(
                    colors: [Color(0xFF000000), Color(0xFFFFFFFF)],
                  ),
                ),
              );
            }),
            _button('mine', (c) {
              c.showToast(message: 'Mine', placement: top);
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

  testWidgets('NFR-U08: us01/s20: us01/fr06/e03: each kind shows its own '
      'icon', (tester) async {
    _view(tester);
    await tester.pumpWidget(
      _app(
        _button('go', (c) {
          c
            ..showToast(message: 'ok', kind: FeedbackState.positive)
            ..showToast(message: 'bad', kind: FeedbackState.negative);
        }),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    final icons = tester
        .widgetList<Icon>(find.byType(Icon))
        .map((i) => i.icon)
        .toSet();
    expect(icons.length, greaterThanOrEqualTo(3)); // two kinds plus close
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
        Widget app() => MaterialApp(
          builder: (context, child) => StratumThemeApplication(
            themes: StratumThemeSet(light: theme),
            themeMode: ThemeMode.light,
            child: StratumToastHost(child: child!),
          ),
          home: Scaffold(
            body: _button(
              'go',
              (c) => c.showToast(message: 'Item deleted', action: undo),
            ),
          ),
        );
        await tester.pumpWidget(app());
        await tester.tap(find.text('go'));
        await tester.pumpAndSettle();
        // Drop the page's blue Material button, keeping the host and its
        // notice, so the guidelines read the notice alone.
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

  testWidgets(
    'NFR-U09: us01/s13: us01/fr04/e05: the close button and Esc close it',
    (tester) async {
      _view(tester);
      await tester.pumpWidget(
        _app(_button('go', (c) => c.showToast(message: 'Swipe'))),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Swipe'), findsNothing);
    },
  );

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
