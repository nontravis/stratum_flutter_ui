import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/components/common/base/disabled.dart';
import 'package:stratum_ui/src/src.dart';

import '../fakes/fake_stratum_theme.dart';

/// An app component on the stateless base: a button that shows its state.
class _Button extends StratumStatelessWidget {
  const new({super.disabled, super.state, super.loading, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Save',
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 100,
        height: 40,
        // Excluded so the merged node reads only the explicit label
        // above, not the visual state text too.
        child: ExcludeSemantics(child: Text(state.name)),
      ),
    ),
  );
}

/// A component that draws its own disabled look (US-07 FR-04 E01).
class _OwnLook extends StratumStatelessWidget {
  const new({super.disabled, this.onTap});

  final VoidCallback? onTap;

  @override
  bool get dimsWhenDisabled => false;

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: const SizedBox(width: 100, height: 40),
  );
}

/// An app subclass of a component that turns the dimming off (FR-04 E02).
class _BrandButton extends _Button {
  const new({super.disabled, super.onTap});

  @override
  bool get dimsWhenDisabled => false;
}

/// A decorative component that declares no semantics, as a caret does
/// (US-07 FR-03 E01).
class _Caret extends StratumStatelessWidget {
  const new({super.disabled});

  @override
  bool get contributesSemantics => false;

  @override
  Widget build(BuildContext context) => const SizedBox(width: 2, height: 20);
}

/// The same declaration on the stateful base.
class _BlinkingCaret extends StratumStatefulWidget {
  const new({super.disabled});

  @override
  bool get contributesSemantics => false;

  @override
  State<_BlinkingCaret> createState() => _BlinkingCaretState();
}

class _BlinkingCaretState extends State<_BlinkingCaret> {
  @override
  Widget build(BuildContext context) => const SizedBox(width: 2, height: 20);
}

/// A component on the stateful base that holds an open section.
class _Section extends StratumStatefulWidget {
  const new({super.disabled});

  @override
  State<_Section> createState() => _SectionState();
}

class _SectionState extends State<_Section> {
  bool open = false;

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: () => setState(() => open = !open),
    child: SizedBox(
      width: 100,
      height: 40,
      child: Text(open ? 'open' : 'closed'),
    ),
  );
}

class _Plain extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) => const SizedBox(width: 10, height: 10);
}

/// A stateless component that breaks the box-root rule (US-07 FR-01 E07).
class _ExpandedStateless extends StratumStatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) => const Expanded(child: SizedBox());
}

/// A stateful component that breaks the box-root rule (US-07 FR-01 E07).
class _ExpandedStateful extends StratumStatefulWidget {
  const new();

  @override
  State<_ExpandedStateful> createState() => _ExpandedStatefulState();
}

class _ExpandedStatefulState extends State<_ExpandedStateful> {
  @override
  Widget build(BuildContext context) => const Expanded(child: SizedBox());
}

StratumDisabled _wrapOf(WidgetTester tester, Finder component) =>
    tester.widget<StratumDisabled>(
      find.descendant(of: component, matching: find.byType(StratumDisabled)),
    );

double _opacityOf(WidgetTester tester, Finder component) => tester
    .widget<Opacity>(
      find.descendant(of: component, matching: find.byType(Opacity)).first,
    )
    .opacity;

void main() {
  group('the bases wrap every component', () {
    testWidgets('us07/fr01, us07/fr01/e04, us07/s10: an app component on the '
        'stateless base dims at 0.5', (tester) async {
      await tester.pumpWidget(themedHost(const _Button(disabled: true)));

      expect(_wrapOf(tester, find.byType(_Button)).disabled, isTrue);
      expect(_opacityOf(tester, find.byType(_Button)), 0.5);
    });

    testWidgets('us07/fr01: a component on the stateful base dims at 0.5', (
      tester,
    ) async {
      await tester.pumpWidget(themedHost(const _Section(disabled: true)));

      expect(_wrapOf(tester, find.byType(_Section)).disabled, isTrue);
      expect(_opacityOf(tester, find.byType(_Section)), 0.5);
    });

    testWidgets('us07/s7, us07/fr01/e01: enabled again, a section keeps its '
        'state at full opacity', (tester) async {
      await tester.pumpWidget(themedHost(const _Section()));
      await tester.tap(find.byType(_Section));
      await tester.pump();
      final state = tester.state(find.byType(_Section));

      await tester.pumpWidget(themedHost(const _Section(disabled: true)));
      await tester.pumpWidget(themedHost(const _Section()));

      expect(tester.state(find.byType(_Section)), same(state));
      expect(find.text('open'), findsOneWidget);
      expect(_opacityOf(tester, find.byType(_Section)), 1.0);
    });

    testWidgets('us07/fr01/e05: disabled with pressed and loading: the wrap '
        'reads disabled alone, and the component keeps its own look', (
      tester,
    ) async {
      await tester.pumpWidget(
        themedHost(
          const _Button(
            disabled: true,
            state: FullWidgetState.pressed,
            loading: true,
          ),
        ),
      );

      expect(find.text('pressed'), findsOneWidget);
      expect(_wrapOf(tester, find.byType(_Button)).disabled, isTrue);
      expect(_opacityOf(tester, find.byType(_Button)), 0.5);
    });

    testWidgets('us07/fr01/e06: a widget on neither base, the wrapper '
        'included, gets no wrapper', (tester) async {
      await tester.pumpWidget(
        themedHost(
          const Column(
            mainAxisSize: MainAxisSize.min,
            children: [_Plain(), _Button()],
          ),
        ),
      );

      expect(
        find.ancestor(
          of: find.byType(_Plain),
          matching: find.byType(StratumDisabled),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byType(StratumDisabled),
          matching: find.byType(StratumDisabled),
        ),
        findsNothing,
      );
    });

    testWidgets('us07/s11, us07/s5: a disabled button refuses a tap and reads '
        'as disabled', (tester) async {
      final handle = tester.ensureSemantics();
      var saved = 0;
      await tester.pumpWidget(
        themedHost(_Button(disabled: true, onTap: () => saved++)),
      );

      await tester.tap(find.byType(_Button), warnIfMissed: false);
      await tester.pump(kDoubleTapTimeout);

      expect(saved, 0);
      expect(
        tester.getSemantics(find.byType(StratumDisabled)),
        isSemantics(label: 'Save', hasEnabledState: true, isEnabled: false),
      );
      handle.dispose();
    });

    testWidgets('a component with no theme above builds while enabled, on '
        'either base', (tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [_Button(), _Section()],
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });
  });

  group('box root', () {
    final cases = <(String, Widget, Type)>[
      ('the stateless base', const _ExpandedStateless(), _ExpandedStateless),
      ('the stateful base', const _ExpandedStateful(), _ExpandedStateful),
    ];
    for (final (name, component, type) in cases) {
      testWidgets('us07/fr01/e07: a component on $name whose build returns '
          'Expanded fails the debug assertion that names the fix', (
        tester,
      ) async {
        await tester.pumpWidget(themedHost(component));

        expect(
          tester.takeException(),
          isA<AssertionError>().having(
            (error) => error.message.toString(),
            'message',
            allOf(
              contains('Incorrect use of ParentDataWidget'),
              contains(type.toString()),
              contains('Expanded'),
              contains('call site'),
            ),
          ),
        );
      });
    }
  });

  group('dimsWhenDisabled', () {
    final cases = <(String, Widget Function(VoidCallback), Type)>[
      (
        'us07/fr04/e01: a component with its own disabled look',
        (onTap) => _OwnLook(disabled: true, onTap: onTap),
        _OwnLook,
      ),
      (
        'us07/fr04/e02, us03/fr01: an app subclass of a component',
        (onTap) => _BrandButton(disabled: true, onTap: onTap),
        _BrandButton,
      ),
    ];
    for (final (name, build, type) in cases) {
      testWidgets('us07/fr04, us07/s9: $name keeps full opacity and every '
          'other disabled rule', (tester) async {
        var taps = 0;
        await tester.pumpWidget(themedHost(build(() => taps++)));

        expect(_opacityOf(tester, find.byType(type)), 1.0);
        expect(_wrapOf(tester, find.byType(type)).dims, isFalse);
        expect(_wrapOf(tester, find.byType(type)).disabled, isTrue);

        await tester.tap(find.byType(type), warnIfMissed: false);
        await tester.pump(kDoubleTapTimeout);
        expect(taps, 0);
      });
    }
  });

  group('contributesSemantics', () {
    final cases = <(String, Widget, Type)>[
      ('the stateless base', const _Caret(disabled: true), _Caret),
      (
        'the stateful base',
        const _BlinkingCaret(disabled: true),
        _BlinkingCaret,
      ),
    ];
    for (final (name, component, type) in cases) {
      testWidgets('us07/fr03/e01, us07/s6, us03/fr01: a component on $name '
          'that declares no semantics gets no disabled node and still '
          'dims', (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          themedHost(
            Semantics(container: true, label: 'host', child: component),
          ),
        );

        expect(
          _wrapOf(tester, find.byType(type)).contributesSemantics,
          isFalse,
        );
        expect(
          tester.getSemantics(find.byType(type)),
          isSemantics(label: 'host', hasEnabledState: false),
        );
        expect(_opacityOf(tester, find.byType(type)), 0.5);
        handle.dispose();
      });
    }

    testWidgets('us03/fr01: both bases declare semantics by default', (
      tester,
    ) async {
      await tester.pumpWidget(
        themedHost(
          const Column(
            mainAxisSize: MainAxisSize.min,
            children: [_Button(disabled: true), _Section(disabled: true)],
          ),
        ),
      );

      expect(
        _wrapOf(tester, find.byType(_Button)).contributesSemantics,
        isTrue,
      );
      expect(
        _wrapOf(tester, find.byType(_Section)).contributesSemantics,
        isTrue,
      );
    });
  });
}
