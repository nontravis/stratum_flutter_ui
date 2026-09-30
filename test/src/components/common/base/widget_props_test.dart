import 'package:flutter/material.dart';
import 'package:flutter_falmodel/flutter_falmodel.dart' show FullWidgetState;
import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/components/common/base/stateful_widget.dart';
import 'package:stratum_ui/src/components/common/base/stateless_widget.dart';
import 'package:stratum_ui/src/components/common/base/widget_props.dart';
import 'package:stratum_ui/src/components/common/model/widget_style.dart';
import 'package:stratum_ui/src/components/common/responsive/window_size_scope.dart';
import 'package:stratum_ui/src/themes/constant/widget_size.dart';
import 'package:stratum_ui/src/themes/constant/window_size.dart';
import 'package:stratum_ui/src/themes/theme_application.dart';
import 'package:stratum_ui/src/themes/theme_data.dart';

class _StatelessProbe extends StratumStatelessWidget {
  const new({
    super.size,
    super.themeMode,
    super.windowSize,
    super.customStyle,
  });

  @override
  Widget build(BuildContext context) => const SizedBox();
}

class _StatefulProbe extends StratumStatefulWidget {
  const new({super.size});

  @override
  State<_StatefulProbe> createState() => _StatefulProbeState();
}

class _StatefulProbeState extends State<_StatefulProbe> {
  @override
  Widget build(BuildContext context) => const SizedBox();
}

class _FakeTheme extends Fake implements StratumThemeData {
  new(this.defaultWidgetSize);

  @override
  final WidgetSize defaultWidgetSize;
}

final _light = _FakeTheme(WidgetSize.small);
final _dark = _FakeTheme(WidgetSize.large);

/// Every prop of [props], in constructor order.
List<Object?> _props(StratumWidgetProps props) => [
  props.size,
  props.color,
  props.themeMode,
  props.windowSize,
  props.state,
  props.feedbackState,
  props.disabled,
  props.loading,
  props.debug,
  props.customStyle,
];

Widget _themed(Widget child, {ThemeMode themeMode = ThemeMode.light}) =>
    StratumThemeApplication(
      themeMode: themeMode,
      lightTheme: _light,
      darkTheme: _dark,
      child: child,
    );

/// Pumps a reader, wrapped by [wrap] when given, and returns what [read]
/// returned during its build.
Future<T> _readInBuild<T>(
  WidgetTester tester,
  T Function(BuildContext context) read, {
  Widget Function(Widget child)? wrap,
}) async {
  late T result;
  final reader = Builder(
    builder: (context) {
      result = read(context);
      return const SizedBox();
    },
  );
  await tester.pumpWidget(wrap == null ? reader : wrap(reader));
  return result;
}

void main() {
  test('StratumStatelessWidget defaults to normal with no overrides', () {
    expect(_props(const _StatelessProbe()), [
      null,
      null,
      null,
      null,
      FullWidgetState.normal,
      null,
      false,
      false,
      false,
      null,
    ]);
  });

  group('resolveSize', () {
    testWidgets('returns the given size without a theme in the tree', (
      tester,
    ) async {
      final size = await _readInBuild(
        tester,
        const _StatelessProbe(size: WidgetSize.huge).resolveSize,
      );

      expect(size, WidgetSize.huge);
    });

    testWidgets('falls back to the theme defaultWidgetSize', (tester) async {
      final size = await _readInBuild(
        tester,
        const _StatelessProbe().resolveSize,
        wrap: _themed,
      );

      expect(size, WidgetSize.small);
    });
  });

  group('resolveWindowSize', () {
    testWidgets('returns the given window size without a WindowSizeScope', (
      tester,
    ) async {
      final windowSize = await _readInBuild(
        tester,
        const _StatelessProbe(windowSize: WindowSize.desktop)
            .resolveWindowSize,
      );

      expect(windowSize, WindowSize.desktop);
    });

    testWidgets('reads the nearest WindowSizeScope when windowSize is null', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(900, 800);
      addTearDown(tester.view.reset);

      final windowSize = await _readInBuild(
        tester,
        const _StatelessProbe().resolveWindowSize,
        wrap: (child) => WindowSizeScope(child: child),
      );

      expect(windowSize, WindowSize.tablet);
    });

    testWidgets('throws a FlutterError when null and no scope exists', (
      tester,
    ) async {
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            const _StatelessProbe().resolveWindowSize(context);
            return const SizedBox();
          },
        ),
      );

      expect(
        tester.takeException(),
        isA<FlutterError>().having(
          (error) => error.message,
          'message',
          contains('No WindowSizeScope found'),
        ),
      );
    });
  });

  group('resolveStyle', () {
    const defaults = WidgetStyle(
      padding: EdgeInsets.all(8),
      opacity: 0.5,
      dropShadow: [BoxShadow(blurRadius: 4)],
    );

    test('returns the defaults when customStyle is null', () {
      expect(const _StatelessProbe().resolveStyle(defaults), same(defaults));
    });

    test('applies each non-null customStyle field over the defaults', () {
      final style = const _StatelessProbe(
        customStyle: WidgetStyle(opacity: 1),
      ).resolveStyle(defaults);

      expect(style.opacity, 1);
      expect(style.padding, const EdgeInsets.all(8));
      expect(style.dropShadow, defaults.dropShadow);
    });

    test('clears default shadows when customStyle passes an empty list', () {
      final style = const _StatelessProbe(
        customStyle: WidgetStyle(dropShadow: []),
      ).resolveStyle(defaults);

      expect(style.dropShadow, isEmpty);
    });
  });

  group('resolveTheme', () {
    testWidgets('returns the app theme when themeMode is null', (
      tester,
    ) async {
      final theme = await _readInBuild(
        tester,
        const _StatelessProbe().resolveTheme,
        wrap: _themed,
      );

      expect(theme, same(_light));
    });

    testWidgets('themeMode overrides the app theme mode', (tester) async {
      final theme = await _readInBuild(
        tester,
        const _StatelessProbe(themeMode: ThemeMode.dark).resolveTheme,
        wrap: _themed,
      );

      expect(theme, same(_dark));
    });

    testWidgets('ThemeMode.system follows the platform brightness', (
      tester,
    ) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

      final theme = await _readInBuild(
        tester,
        const _StatelessProbe(themeMode: ThemeMode.system).resolveTheme,
        wrap: _themed,
      );

      expect(theme, same(_dark));
    });

    testWidgets('throws a FlutterError without a StratumThemeApplication', (
      tester,
    ) async {
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            const _StatelessProbe().resolveTheme(context);
            return const SizedBox();
          },
        ),
      );

      expect(
        tester.takeException(),
        isA<FlutterError>().having(
          (error) => error.message,
          'message',
          contains('StratumThemeApplication.of() called'),
        ),
      );
    });
  });

  group('StratumStatefulWidget', () {
    test('has the same defaults as StratumStatelessWidget', () {
      expect(
        _props(const _StatefulProbe()),
        _props(const _StatelessProbe()),
      );
    });

    testWidgets('resolveSize returns the given size', (tester) async {
      final size = await _readInBuild(
        tester,
        const _StatefulProbe(size: WidgetSize.huge).resolveSize,
      );

      expect(size, WidgetSize.huge);
    });

    testWidgets('resolveSize falls back to the theme defaultWidgetSize', (
      tester,
    ) async {
      final size = await _readInBuild(
        tester,
        const _StatefulProbe().resolveSize,
        wrap: _themed,
      );

      expect(size, WidgetSize.small);
    });
  });
}
