import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';
import 'package:stratum_ui/src/themes/theme_font_loader.dart';

import 'theme_runtime_fakes.dart';

Widget _text(String text) => Text(text, textDirection: TextDirection.ltr);

/// A preloader over [bundle] that shows `loading`, `error <type>`, and
/// `ready <active id>`, unless [builder] or [withError] says otherwise.
Widget _preloader(
  FakeThemeBundle bundle, {
  String? initialThemeId,
  ValueChanged<String>? onThemeChanged,
  bool withError = true,
  Widget Function(BuildContext context, StratumThemeController controller)?
  builder,
}) => DefaultAssetBundle(
  bundle: bundle,
  child: StratumThemePreloader(
    initialThemeId: initialThemeId,
    onThemeChanged: onThemeChanged,
    loading: (context) => _text('loading'),
    error: withError
        ? (context, error) => _text('error ${error.runtimeType}')
        : null,
    builder:
        builder ??
        (context, controller) => _text('ready ${controller.activeId}'),
  ),
);

void main() {
  setUp(ThemeFontLoader.reset);

  testWidgets('us01/fr03/e03: the loading screen shows until the start '
      'theme is active, then the builder', (tester) async {
    await tester.pumpWidget(
      _preloader(
        FakeThemeBundle(themes: {'brand': appTheme()}),
        initialThemeId: 'brand',
      ),
    );
    expect(find.text('loading'), findsOneWidget);

    await tester.pumpAndSettle();

    expect(find.text('ready brand'), findsOneWidget);
  });

  testWidgets('us01/fr03/e01: a start theme that fails to parse shows the '
      'error screen', (tester) async {
    await tester.pumpWidget(
      _preloader(
        FakeThemeBundle(themes: {'brand': brokenTheme()}),
        initialThemeId: 'brand',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('error StratumThemeFormatException'), findsOneWidget);
  });

  testWidgets('with no error screen, the exception is reported', (
    tester,
  ) async {
    await tester.pumpWidget(
      _preloader(
        FakeThemeBundle(themes: {'brand': brokenTheme()}),
        initialThemeId: 'brand',
        withError: false,
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isA<StratumThemeFormatException>());
  });

  testWidgets('us03/fr01/e02, us01/fr03/e02: a saved id that names no theme '
      'starts on default and reports it', (tester) async {
    final changes = <String>[];
    await tester.pumpWidget(
      _preloader(
        FakeThemeBundle(),
        initialThemeId: 'gone',
        onThemeChanged: changes.add,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('ready default'), findsOneWidget);
    expect(changes, ['default']);
  });

  testWidgets('us02/s1: the builder hands over a controller the app '
      'switches through', (tester) async {
    await tester.pumpWidget(
      _preloader(
        FakeThemeBundle(themes: {'brand': appTheme()}),
        builder: (context, controller) => StratumThemeApplication.controlled(
          controller: controller,
          themeMode: ThemeMode.light,
          child: Builder(
            builder: (context) =>
                _text('active ${StratumThemeController.of(context).activeId}'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('active default'), findsOneWidget);

    final context = tester.element(find.text('active default'));
    await StratumThemeController.of(context).switchTo('brand');
    await tester.pump();

    expect(find.text('active brand'), findsOneWidget);
  });

  testWidgets('disposes its controller when it leaves the tree', (
    tester,
  ) async {
    late StratumThemeController controller;
    await tester.pumpWidget(
      _preloader(
        FakeThemeBundle(),
        builder: (context, value) {
          controller = value;
          return _text('ready');
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.pumpWidget(const SizedBox());

    expect(() => controller.addListener(() {}), throwsFlutterError);
  });

  testWidgets('unmounted before preload completes', (tester) async {
    final bundle = FakeThemeBundle();
    final release = bundle.hold[packageDefaultKey] = Completer<void>();
    await tester.pumpWidget(_preloader(bundle));

    await tester.pumpWidget(const SizedBox());
    release.complete();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
