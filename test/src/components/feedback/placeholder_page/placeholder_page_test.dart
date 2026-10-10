import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/components/common/base/disabled.dart';
import 'package:stratum_ui/src/src.dart';

import '../../common/fakes/fake_stratum_theme.dart';

// NFR-U02 n/a: no interactive node; the scroll view follows FO-06
// keyboard scrolling when content overflows.
// NFR-U03 n/a: no animation.
// NFR-U05 n/a: no interactive target.
// NFR-U08 n/a: no state.
// NFR-E01 n/a: not a component (d01 glossary, "built on the component
// base"); the icon stays a fixed 48 (R4 Q5); set B design R6.
// NFR-E02 n/a: not a component (d01 glossary, "built on the component
// base"); set B design R6.

const _title = 'Reports';
const _message = 'This screen arrives in the next release.';
const _iconLabel = 'Under construction';

Widget _widget({String? title, String? message, bool icon = true}) =>
    StratumPlaceholderPage(
      title: title,
      message: message,
      icon: icon
          ? const Icon(Icons.construction, semanticLabel: _iconLabel)
          : null,
    );

Finder get _page => find.byType(StratumPlaceholderPage);

/// The texts the page itself shows; an [Icon] paints a [RichText], not a
/// [Text], so it is not counted.
Finder get _texts => find.descendant(of: _page, matching: find.byType(Text));

/// [child] under a bare [Localizations] for [locale], over [themedHost].
Widget _localeHost(Locale locale, Widget child) => Localizations(
  locale: locale,
  delegates: const [DefaultWidgetsLocalizations.delegate],
  child: themedHost(child),
);

/// [child] on the page background of [theme], else [fakeTheme]: text
/// contrast reads against the surface an app paints behind the widget.
Widget _pageHost(Widget child, {StratumThemeData? theme}) {
  final data = theme ?? fakeTheme;
  return themedHost(
    ColoredBox(color: data.color.background.defaults.normal, child: child),
    theme: data,
  );
}

StratumTheme _theme(WidgetTester tester) =>
    StratumTheme.of(tester.element(_page));

Color? _color(WidgetTester tester, String text) =>
    tester.widget<Text>(find.text(text)).style?.color;

void main() {
  group('us01/fr01: the placeholder content', () {
    testWidgets('us01/fr01/e01: with no message and no icon the title '
        'shows alone', (tester) async {
      await tester.pumpWidget(themedHost(_widget(title: _title, icon: false)));
      expect(find.text(_title), findsOneWidget);
      expect(_texts, findsOneWidget);
      expect(find.byType(Icon), findsNothing);
    });

    testWidgets('us01/fr01/e02: the icon shows above the title and the '
        'message below it, spaced by the theme', (tester) async {
      await tester.pumpWidget(
        themedHost(_widget(title: _title, message: _message)),
      );
      final icon = tester.getRect(find.byType(Icon));
      final title = tester.getRect(find.text(_title));
      final message = tester.getRect(find.text(_message));
      expect(title.top - icon.bottom, _theme(tester).space.md);
      expect(message.top - title.bottom, _theme(tester).space.sm);
    });

    testWidgets('us01/fr01: the page fills its parent and centers its '
        'content', (tester) async {
      await tester.pumpWidget(
        themedHost(
          SizedBox(
            width: 300,
            height: 400,
            child: _widget(title: _title, message: _message),
          ),
        ),
      );
      final page = tester.getRect(_page);
      expect(page.size, const Size(300, 400));
      final top = tester.getRect(find.byType(Icon)).top;
      final bottom = tester.getRect(find.text(_message)).bottom;
      expect((top + bottom) / 2, closeTo(page.center.dy, 0.5));
      expect(
        tester.getCenter(find.text(_title)).dx,
        closeTo(page.center.dx, 0.5),
      );
    });

    testWidgets('us01/fr01/e03: the page adds no app bar and no back '
        'action', (tester) async {
      await tester.pumpWidget(themedHost(_widget(message: _message)));
      for (final type in [AppBar, BackButton, Scaffold]) {
        expect(
          find.descendant(of: _page, matching: find.byType(type)),
          findsNothing,
        );
      }
    });

    testWidgets('us01/fr01: the icon is 48 in the secondary icon color', (
      tester,
    ) async {
      await tester.pumpWidget(themedHost(_widget()));
      final icon = find.byType(Icon);
      final iconTheme = IconTheme.of(tester.element(icon));
      expect(iconTheme.size, StratumPlaceholderPage.iconSize);
      expect(StratumPlaceholderPage.iconSize, 48);
      expect(
        iconTheme.color,
        isSameColorAs(fakeTheme.color.icon.defaults.secondary),
      );
      expect(tester.getSize(icon), const Size(48, 48));
    });

    testWidgets('us01/fr01: the title is a 20 header and the message 16 '
        'body text, both in the primary text color', (tester) async {
      await tester.pumpWidget(
        themedHost(_widget(title: _title, message: _message)),
      );
      final context = tester.element(_page);
      expect(
        tester.widget<Text>(find.text(_title)).style,
        StratumTextStyle.header.s20.colorPrimary.build(context),
      );
      expect(
        tester.widget<Text>(find.text(_message)).style,
        StratumTextStyle.body.s16.colorPrimary.build(context),
      );
      for (final text in [_title, _message]) {
        expect(
          _color(tester, text),
          isSameColorAs(fakeTextColors[FontColor.primary]!),
        );
        expect(
          tester.widget<Text>(find.text(text)).textAlign,
          TextAlign.center,
        );
      }
    });

    testWidgets('us01/fr01/e04: at twice the text size the text wraps, the '
        'page scrolls, and the icon stays 48', (tester) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: themedHost(
            SizedBox(
              width: 200,
              height: 150,
              child: _widget(title: _title, message: _message * 3),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.text(_message * 3)).width,
        lessThanOrEqualTo(200),
      );
      final scroll = tester.state<ScrollableState>(
        find.descendant(of: _page, matching: find.byType(Scrollable)),
      );
      expect(scroll.position.maxScrollExtent, greaterThan(0));
      expect(tester.getSize(find.byType(Icon)), const Size(48, 48));
    });

    testWidgets('us01/fr01/e05: a screen reader reads the title as a '
        'heading, the message as text, and skips the icon', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        themedHost(_widget(title: _title, message: _message)),
      );
      expect(
        tester.getSemantics(find.text(_title)),
        isSemantics(label: _title, isHeader: true),
      );
      expect(find.bySemanticsLabel(_message), findsOneWidget);
      expect(find.bySemanticsLabel(_iconLabel), findsNothing);
      handle.dispose();
    });

    testWidgets('us01/fr01/s03-6: a caller icon with its own size still '
        'lays out at 48', (tester) async {
      await tester.pumpWidget(
        themedHost(
          const StratumPlaceholderPage(
            title: _title,
            icon: Icon(Icons.construction, size: 96, semanticLabel: _iconLabel),
          ),
        ),
      );
      expect(tester.getRect(find.byType(Icon)).size, const Size(48, 48));
    });

    testWidgets('us01/fr01/e04: an unbroken token at twice the text size '
        'wraps with no exception and the page scrolls', (tester) async {
      final token = 'x' * 200;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: themedHost(
            SizedBox(
              width: 200,
              height: 150,
              child: _widget(title: _title, message: token),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      final scroll = tester.state<ScrollableState>(
        find.descendant(of: _page, matching: find.byType(Scrollable)),
      );
      expect(scroll.position.maxScrollExtent, greaterThan(0));
    });
  });

  group('us01/fr02: a default title in English or Thai', () {
    testWidgets('us01/fr02/e01: a Thai locale with no title shows the Thai '
        'title', (tester) async {
      await tester.pumpWidget(
        _localeHost(const Locale('th'), _widget(icon: false)),
      );
      expect(find.text('เร็วๆ นี้'), findsOneWidget);
    });

    testWidgets('us01/fr02/e02: a Japanese locale with no title shows the '
        'English title', (tester) async {
      await tester.pumpWidget(
        _localeHost(const Locale('ja'), _widget(icon: false)),
      );
      expect(find.text('Coming soon'), findsOneWidget);
    });

    testWidgets('us01/fr02/e03: a passed title replaces the built-in one, '
        'for a screen reader too', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _localeHost(const Locale('th'), _widget(title: _title)),
      );
      expect(find.text('เร็วๆ นี้'), findsNothing);
      expect(find.bySemanticsLabel('เร็วๆ นี้'), findsNothing);
      expect(
        tester.getSemantics(find.text(_title)),
        isSemantics(label: _title, isHeader: true),
      );
      handle.dispose();
    });

    testWidgets('us01/fr02/e04: no message passed shows no message', (
      tester,
    ) async {
      await tester.pumpWidget(
        _localeHost(const Locale('en'), _widget(title: _title)),
      );
      expect(_texts, findsOneWidget);
    });
  });

  group('us01: mark a screen not built yet', () {
    testWidgets('us01/s1: a Thai app that passes no text shows the Thai '
        'title alone, centered', (tester) async {
      await tester.pumpWidget(
        _localeHost(const Locale('th'), const StratumPlaceholderPage()),
      );
      expect(find.text('เร็วๆ นี้'), findsOneWidget);
      expect(_texts, findsOneWidget);
      expect(find.byType(Icon), findsNothing);
      expect(
        tester.getCenter(find.text('เร็วๆ นี้')),
        offsetMoreOrLessEquals(tester.getCenter(_page), epsilon: 0.5),
      );
    });

    testWidgets('us01/s2: an English app shows the English title', (
      tester,
    ) async {
      await tester.pumpWidget(
        _localeHost(const Locale('en'), const StratumPlaceholderPage()),
      );
      expect(find.text('Coming soon'), findsOneWidget);
    });

    testWidgets('us01/s3: a Japanese app shows the English title', (
      tester,
    ) async {
      await tester.pumpWidget(
        _localeHost(const Locale('ja'), const StratumPlaceholderPage()),
      );
      expect(find.text('Coming soon'), findsOneWidget);
    });

    testWidgets("us01/s4: the app's own title replaces the built-in one", (
      tester,
    ) async {
      await tester.pumpWidget(
        _localeHost(
          const Locale('th'),
          const StratumPlaceholderPage(title: _title),
        ),
      );
      expect(find.text(_title), findsOneWidget);
      expect(find.text('เร็วๆ นี้'), findsNothing);
    });

    testWidgets('us01/s5: the icon shows above the title and the message '
        'below it', (tester) async {
      await tester.pumpWidget(
        themedHost(_widget(title: _title, message: _message)),
      );
      final title = tester.getRect(find.text(_title));
      expect(tester.getRect(find.byType(Icon)).bottom, lessThan(title.top));
      expect(
        tester.getRect(find.text(_message)).top,
        greaterThan(title.bottom),
      );
    });

    testWidgets("us01/s6: inside the app's page only the app's app bar and "
        'back button show above it', (tester) async {
      await tester.pumpWidget(
        themedHost(
          MaterialApp(
            home: Scaffold(
              appBar: AppBar(
                leading: const BackButton(),
                title: const Text('Reports'),
              ),
              body: _widget(message: _message),
            ),
          ),
        ),
      );
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.byType(BackButton), findsOneWidget);
      expect(
        tester.getRect(_page).top,
        greaterThanOrEqualTo(tester.getRect(find.byType(AppBar)).bottom),
      );
    });

    testWidgets('us01/s7: a screen reader reads the Thai built-in title as a '
        'heading and skips the icon', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_localeHost(const Locale('th'), _widget()));
      expect(
        tester.getSemantics(find.text('เร็วๆ นี้')),
        isSemantics(label: 'เร็วๆ นี้', isHeader: true),
      );
      expect(find.semantics.byLabel(_iconLabel), findsNothing);
      handle.dispose();
    });

    testWidgets('us01/s8: at twice the text size a long message wraps and '
        'the page scrolls to show it all', (tester) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: themedHost(
            SizedBox(
              width: 200,
              height: 150,
              child: _widget(title: _title, message: _message * 3),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.text(_message * 3)).width,
        lessThanOrEqualTo(200),
      );
      final scroll = tester.state<ScrollableState>(
        find.descendant(of: _page, matching: find.byType(Scrollable)),
      );
      expect(scroll.position.maxScrollExtent, greaterThan(0));
    });
  });

  group('StratumPlaceholderPage accessibility gate', () {
    testWidgets('NFR-U01: text contrast and labeled tap targets pass', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_pageHost(_widget(message: _message)));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    });

    testWidgets('NFR-U04: twice the text size shows no overflow', (
      tester,
    ) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: themedHost(_widget(message: _message)),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('NFR-U06: the title node reads as a labeled heading', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(themedHost(_widget(title: _title)));
      expect(
        tester.getSemantics(find.text(_title)),
        isSemantics(label: _title, isHeader: true),
      );
      handle.dispose();
    });

    testWidgets('NFR-U07: text contrast passes in every bundled theme', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final themes = [
        defaultThemeSet.light,
        defaultThemeSet.dark,
        defaultThemeSet.highContrastLight,
        defaultThemeSet.highContrastDark,
      ].nonNulls;
      for (final theme in themes) {
        await tester.pumpWidget(
          _pageHost(_widget(message: _message), theme: theme),
        );
        await tester.pumpAndSettle();
        await expectLater(tester, meetsGuideline(textContrastGuideline));
      }
      handle.dispose();
    });

    testWidgets('s03/inv6: the title color follows the theme', (tester) async {
      await tester.pumpWidget(
        _pageHost(_widget(title: _title), theme: defaultThemeSet.light),
      );
      final light = _color(tester, _title);
      await tester.pumpWidget(
        _pageHost(_widget(title: _title), theme: defaultThemeSet.dark),
      );
      expect(_color(tester, _title), isNot(isSameColorAs(light!)));
    });

    testWidgets('s03/inv5: no StratumDisabled wraps the page', (tester) async {
      await tester.pumpWidget(themedHost(_widget(title: _title)));
      expect(find.byType(StratumDisabled), findsNothing);
    });

    testWidgets('NFR-U09: the overflowing page scrolls by key alone', (
      tester,
    ) async {
      final before = FocusNode();
      addTearDown(before.dispose);
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: themedHost(
            Shortcuts(
              shortcuts: WidgetsApp.defaultShortcuts,
              child: Actions(
                actions: WidgetsApp.defaultActions,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Focus(
                      focusNode: before,
                      child: const SizedBox(width: 10, height: 10),
                    ),
                    SizedBox(
                      width: 200,
                      height: 150,
                      child: _widget(title: _title, message: _message * 3),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      before.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
      await tester.pumpAndSettle();
      final scroll = tester.state<ScrollableState>(
        find.descendant(of: _page, matching: find.byType(Scrollable)),
      );
      expect(scroll.position.pixels, greaterThan(0));
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
  });
}
