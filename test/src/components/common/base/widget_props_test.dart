import 'package:flutter/material.dart';
import 'package:flutter_falmodel/flutter_falmodel.dart' show FullWidgetState;
import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/components/common/base/stateful_widget.dart';
import 'package:stratum_ui/src/components/common/base/stateless_widget.dart';
import 'package:stratum_ui/src/components/common/base/widget_props.dart';
import 'package:stratum_ui/src/components/common/model/widget_style.dart';
import 'package:stratum_ui/src/components/common/responsive/window_size_scope.dart';
import 'package:stratum_ui/src/themes/constant/color.dart';
import 'package:stratum_ui/src/themes/constant/widget_size.dart';
import 'package:stratum_ui/src/themes/constant/window_size.dart';
import 'package:stratum_ui/src/themes/theme_application.dart';
import 'package:stratum_ui/src/themes/theme_data.dart';
import 'package:stratum_ui/src/themes/theme_set.dart';
import 'package:stratum_ui/src/themes/tokens/theme_tokens.g.dart';

import '../fakes/fake_stratum_theme.dart';

class _StatelessProbe extends StratumStatelessWidget {
  const new({
    super.size,
    super.color,
    super.themeMode,
    super.windowSize,
    super.customStyle,
  });

  @override
  Widget build(BuildContext context) => const SizedBox();
}

class _StatefulProbe extends StratumStatefulWidget {
  const new({super.size, super.color});

  @override
  State<_StatefulProbe> createState() => _StatefulProbeState();
}

class _StatefulProbeState extends State<_StatefulProbe> {
  @override
  Widget build(BuildContext context) => const SizedBox();
}

/// Overrides [StratumWidgetProps.resolveTheme] to prove [resolveDefaultSize]
/// and the deprecated `resolveSize` read through it (FO-08 US-01 FR-02).
class _StatelessThemeOverrideProbe extends StratumStatelessWidget {
  const new({required this.overrideTheme});

  final StratumThemeData overrideTheme;

  @override
  StratumThemeData resolveTheme(BuildContext context) => overrideTheme;

  @override
  Widget build(BuildContext context) => const SizedBox();
}

/// The stateful twin of [_StatelessThemeOverrideProbe].
class _StatefulThemeOverrideProbe extends StratumStatefulWidget {
  const new({required this.overrideTheme});

  final StratumThemeData overrideTheme;

  @override
  StratumThemeData resolveTheme(BuildContext context) => overrideTheme;

  @override
  State<_StatefulThemeOverrideProbe> createState() =>
      _StatefulThemeOverrideProbeState();
}

class _StatefulThemeOverrideProbeState
    extends State<_StatefulThemeOverrideProbe> {
  @override
  Widget build(BuildContext context) => const SizedBox();
}

final StratumThemeData _light = fakeTheme.copyWith(
  defaultWidgetSize: WidgetSize.small,
);
final StratumThemeData _dark = fakeTheme.copyWith(
  defaultWidgetSize: WidgetSize.large,
);

const _fallback = Color(0xFF0A0B0C);

/// The icon group of [colors], the caret's group.
StratumColorEnumTokens _icon(StratumColorTokens colors) => colors.icon.color;

/// A group that holds [ColorEnum.red] alone: the shape a `<group>.color`
/// class takes once the yaml gains `<group>.color.red` and the generator
/// runs again.
final class _RedOnly implements StratumColorEnumTokens {
  const new();

  static const red = Color(0xFFAA0000);

  @override
  Color? operator [](ColorEnum color) => color == ColorEnum.red ? red : null;
}

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
  props.customStyle,
];

Widget _themed(Widget child, {ThemeMode themeMode = ThemeMode.light}) =>
    StratumThemeApplication(
      themes: StratumThemeSet(light: _light, dark: _dark),
      themeMode: themeMode,
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
  test('fo08/us01/fr01: StratumStatelessWidget holds the nine props at their '
      'defaults', () {
    expect(_props(const _StatelessProbe()), [
      null,
      null,
      null,
      null,
      FullWidgetState.normal,
      null,
      false,
      false,
      null,
    ]);
  });

  group('resolveDefaultSize', () {
    testWidgets('returns the given size without a theme in the tree', (
      tester,
    ) async {
      final size = await _readInBuild(
        tester,
        const _StatelessProbe(size: WidgetSize.huge).resolveDefaultSize,
      );

      expect(size, WidgetSize.huge);
    });

    testWidgets('falls back to the theme defaultWidgetSize', (tester) async {
      final size = await _readInBuild(
        tester,
        const _StatelessProbe().resolveDefaultSize,
        wrap: _themed,
      );

      expect(size, WidgetSize.small);
    });

    testWidgets('fo08/us01/fr02: the deprecated resolveSize returns what '
        'resolveDefaultSize returns', (tester) async {
      final size = await _readInBuild(
        tester,
        // Pins the deprecated alias (FO-08 US-01 FR-02).
        // ignore: deprecated_member_use_from_same_package
        const _StatelessProbe().resolveSize,
        wrap: _themed,
      );

      expect(size, WidgetSize.small);
    });

    testWidgets(
      'fo08/us01/fr02/e04: a dark themeMode reads the dark default size',
      (tester) async {
        final size = await _readInBuild(
          tester,
          const _StatelessProbe(themeMode: ThemeMode.dark).resolveDefaultSize,
          wrap: _themed,
        );

        expect(size, WidgetSize.large);
      },
    );

    testWidgets('fo08/us01/fr02: a subclass that overrides resolveTheme sets '
        'the default size', (tester) async {
      final override = fakeTheme.copyWith(defaultWidgetSize: WidgetSize.huge);
      final probe = _StatelessThemeOverrideProbe(overrideTheme: override);

      final size = await _readInBuild(
        tester,
        probe.resolveDefaultSize,
        wrap: _themed,
      );

      expect(size, WidgetSize.huge);
    });

    testWidgets('fo08/us01/fr02: the deprecated resolveSize follows an '
        'overridden resolveTheme too', (tester) async {
      final override = fakeTheme.copyWith(defaultWidgetSize: WidgetSize.huge);
      final probe = _StatelessThemeOverrideProbe(overrideTheme: override);

      final size = await _readInBuild(
        tester,
        // Pins the deprecated alias (FO-08 US-01 FR-02).
        // ignore: deprecated_member_use_from_same_package
        probe.resolveSize,
        wrap: _themed,
      );

      expect(size, WidgetSize.huge);
    });
  });

  group('resolveWindowSize', () {
    testWidgets('returns the given window size without a WindowSizeScope', (
      tester,
    ) async {
      final windowSize = await _readInBuild(
        tester,
        const _StatelessProbe(windowSize: WindowSize.desktop).resolveWindowSize,
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

    testWidgets('returns the defaults when customStyle is null', (
      tester,
    ) async {
      final style = await _readInBuild(
        tester,
        (context) => const _StatelessProbe().resolveStyle(context, defaults),
      );

      expect(style, same(defaults));
    });

    testWidgets('applies each non-null customStyle field over the defaults', (
      tester,
    ) async {
      final style = await _readInBuild(
        tester,
        (context) =>
            const _StatelessProbe(customStyle: WidgetStyle(opacity: 1))
                .resolveStyle(context, defaults),
      );

      expect(style.opacity, 1);
      expect(style.padding, const EdgeInsets.all(8));
      expect(style.dropShadow, defaults.dropShadow);
    });

    testWidgets('clears default shadows when customStyle passes an empty '
        'list', (tester) async {
      final style = await _readInBuild(
        tester,
        (context) =>
            const _StatelessProbe(customStyle: WidgetStyle(dropShadow: []))
                .resolveStyle(context, defaults),
      );

      expect(style.dropShadow, isEmpty);
    });
  });

  group('resolveTheme', () {
    testWidgets('returns the app theme when themeMode is null', (tester) async {
      final theme = await _readInBuild(
        tester,
        const _StatelessProbe().resolveTheme,
        wrap: _themed,
      );

      expect(theme, same(_light));
    });

    testWidgets('follows a dark app theme mode when themeMode is null', (
      tester,
    ) async {
      final theme = await _readInBuild(
        tester,
        const _StatelessProbe().resolveTheme,
        wrap: (child) => _themed(child, themeMode: ThemeMode.dark),
      );

      expect(theme, same(_dark));
    });

    testWidgets('themeMode overrides the app theme mode', (tester) async {
      final theme = await _readInBuild(
        tester,
        const _StatelessProbe(themeMode: ThemeMode.dark).resolveTheme,
        wrap: _themed,
      );

      expect(theme, same(_dark));
    });

    testWidgets('ThemeMode.system follows a dark platform brightness', (
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

    testWidgets('ThemeMode.system follows a light platform brightness', (
      tester,
    ) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

      final theme = await _readInBuild(
        tester,
        const _StatelessProbe(themeMode: ThemeMode.system).resolveTheme,
        wrap: (child) => _themed(child, themeMode: ThemeMode.dark),
      );

      expect(theme, same(_light));
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

  group('resolveColor', () {
    testWidgets('fo08/us01/fr03/e01: a null color gives the fallback and reads '
        'no theme', (tester) async {
      final color = await _readInBuild(
        tester,
        (context) =>
            const _StatelessProbe().resolveColor(context, _icon, _fallback),
      );

      expect(color, _fallback);
    });

    testWidgets('fo08/us01/fr03/e01: StratumStatefulWidget with a null color '
        'gives the fallback and reads no theme', (tester) async {
      final color = await _readInBuild(
        tester,
        (context) =>
            const _StatefulProbe().resolveColor(context, _icon, _fallback),
      );

      expect(color, _fallback);
    });

    testWidgets(
      'fo08/us01/fr03/e02, fo08/us01/s5: blue in the icon group gives the '
      "theme's icon.color.blue",
      (tester) async {
        final color = await _readInBuild(
          tester,
          (context) =>
              const _StatelessProbe(color: ColorEnum.blue)
                  .resolveColor(context, _icon, _fallback),
          wrap: _themed,
        );

        expect(color, _light.color.icon.color.blue);
      },
    );

    testWidgets(
      'fo08/us01/fr03/e03, fo08/us01/s6: red, which the icon group lacks, '
      'gives the fallback',
      (tester) async {
        final color = await _readInBuild(
          tester,
          (context) =>
              const _StatelessProbe(color: ColorEnum.red)
                  .resolveColor(context, _icon, _fallback),
          wrap: _themed,
        );

        expect(color, _fallback);
      },
    );

    testWidgets(
      'fo08/us01/fr03/e04: a group that gains a name resolves it with '
      'no change to the resolver',
      (tester) async {
        final color = await _readInBuild(
          tester,
          (context) =>
              const _StatelessProbe(color: ColorEnum.red)
                  .resolveColor(context, (_) => const _RedOnly(), _fallback),
          wrap: _themed,
        );

        expect(color, _RedOnly.red);
      },
    );

    testWidgets(
      'fo08/us01/fr03: each group answers from its own tokens: gray in '
      'background and border, the fallback in icon and text',
      (tester) async {
        final groups =
            <
              String,
              (StratumColorEnumTokens Function(StratumColorTokens), Color)
            >{
              'background': (
                (c) => c.background.color,
                _light.color.background.color.gray,
              ),
              'border': ((c) => c.border.color, _light.color.border.color.gray),
              'icon': (_icon, _fallback),
              'text': ((c) => c.text.color, _fallback),
            };

        for (final MapEntry(key: name, value: (group, expected))
            in groups.entries) {
          final color = await _readInBuild(
            tester,
            (context) =>
                const _StatelessProbe(color: ColorEnum.gray)
                    .resolveColor(context, group, _fallback),
            wrap: _themed,
          );

          expect(color, expected, reason: name);
        }
      },
    );

    testWidgets("fo08/us01/fr03: the component's themeMode picks the dark "
        'token', (tester) async {
      final color = await _readInBuild(
        tester,
        (context) => const _StatelessProbe(
          color: ColorEnum.blue,
          themeMode: ThemeMode.dark,
        ).resolveColor(context, _icon, _fallback),
        wrap: (child) => StratumThemeApplication(
          themes: defaultThemeSet,
          themeMode: ThemeMode.light,
          child: child,
        ),
      );

      final dark = defaultThemeSet.dark!.color.icon.color.blue;
      expect(dark, isNot(defaultThemeSet.light.color.icon.color.blue));
      expect(color, dark);
    });

    testWidgets(
      'fo08/us01/fr03: StratumStatefulWidget resolves the same token',
      (tester) async {
        final color = await _readInBuild(
          tester,
          (context) =>
              const _StatefulProbe(color: ColorEnum.blue)
                  .resolveColor(context, _icon, _fallback),
          wrap: _themed,
        );

        expect(color, _light.color.icon.color.blue);
      },
    );
  });

  group('StratumStatefulWidget', () {
    test('has the same defaults as StratumStatelessWidget', () {
      expect(_props(const _StatefulProbe()), _props(const _StatelessProbe()));
    });

    testWidgets('resolveDefaultSize returns the given size', (tester) async {
      final size = await _readInBuild(
        tester,
        const _StatefulProbe(size: WidgetSize.huge).resolveDefaultSize,
      );

      expect(size, WidgetSize.huge);
    });

    testWidgets(
      'resolveDefaultSize falls back to the theme defaultWidgetSize',
      (tester) async {
        final size = await _readInBuild(
          tester,
          const _StatefulProbe().resolveDefaultSize,
          wrap: _themed,
        );

        expect(size, WidgetSize.small);
      },
    );

    testWidgets('fo08/us01/fr02: a subclass that overrides resolveTheme sets '
        'the default size', (tester) async {
      final override = fakeTheme.copyWith(defaultWidgetSize: WidgetSize.huge);
      final probe = _StatefulThemeOverrideProbe(overrideTheme: override);

      final size = await _readInBuild(
        tester,
        probe.resolveDefaultSize,
        wrap: _themed,
      );

      expect(size, WidgetSize.huge);
    });
  });
}
