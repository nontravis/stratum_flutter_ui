import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/components/common/base/disabled.dart';
import 'package:stratum_ui/src/src.dart';

import '../fakes/fake_stratum_theme.dart';

const _box = SizedBox(width: 40, height: 20);

/// [child] inside a host node labelled [label], so a test can tell whether
/// [child] formed a node of its own.
Widget _host(Widget child, {String label = 'host'}) =>
    themedHost(Semantics(container: true, label: label, child: child));

/// A button with a State of its own, for the structure checks. Its own
/// `Semantics` sits inside it, so [_chain] sees only the wrapper's layers.
class _Kept extends StatefulWidget {
  const new();

  @override
  State<_Kept> createState() => _KeptState();
}

class _KeptState extends State<_Kept> {
  @override
  Widget build(BuildContext context) =>
      Semantics(button: true, label: 'Save', child: _box);
}

/// The widget types from the parent of [_Kept] up to [StratumDisabled].
List<Type> _chain(WidgetTester tester) {
  final types = <Type>[];
  tester.element(find.byType(_Kept)).visitAncestorElements((element) {
    types.add(element.widget.runtimeType);
    return element.widget is! StratumDisabled;
  });
  return types;
}

void main() {
  group('StratumDisabled semantics', () {
    testWidgets('us07/fr03, us07/s5: a disabled component that declares '
        'semantics reads as disabled on one node', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(
          StratumDisabled(
            disabled: true,
            child: Semantics(button: true, label: 'Save', child: _box),
          ),
        ),
      );

      expect(
        tester.getSemantics(find.byType(StratumDisabled)),
        isSemantics(
          label: 'Save',
          isButton: true,
          hasEnabledState: true,
          isEnabled: false,
        ),
      );
      handle.dispose();
    });

    testWidgets('us07/fr03: a disabled component inside another disabled '
        'one reports one node each, unmerged', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(
          StratumDisabled(
            disabled: true,
            child: Semantics(
              label: 'Form',
              child: StratumDisabled(
                disabled: true,
                child: Semantics(button: true, label: 'Save', child: _box),
              ),
            ),
          ),
        ),
      );

      final outer = tester.getSemantics(find.byType(StratumDisabled).first);
      final inner = tester.getSemantics(find.byType(StratumDisabled).last);
      expect(
        outer,
        isSemantics(label: 'Form', hasEnabledState: true, isEnabled: false),
      );
      expect(
        inner,
        isSemantics(
          label: 'Save',
          isButton: true,
          hasEnabledState: true,
          isEnabled: false,
        ),
      );
      expect(outer.childrenCount, 1);
      handle.dispose();
    });

    testWidgets('us07/fr03: a component node of its own sits inside the '
        'disabled node', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(
          StratumDisabled(
            disabled: true,
            child: Semantics(
              container: true,
              button: true,
              label: 'Save',
              child: _box,
            ),
          ),
        ),
      );

      final node = tester.getSemantics(find.byType(StratumDisabled));
      expect(node, isSemantics(hasEnabledState: true, isEnabled: false));
      expect(node.childrenCount, 1);
      expect(
        tester.getSemantics(find.bySemanticsLabel('Save')),
        isSemantics(label: 'Save', isButton: true),
      );
      handle.dispose();
    });

    testWidgets('us07/fr03/e01, us07/s6: a disabled component that declares '
        'no semantics adds no node and no flag', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(
          const StratumDisabled(
            disabled: true,
            contributesSemantics: false,
            child: _box,
          ),
        ),
      );

      expect(
        tester.getSemantics(find.byType(StratumDisabled)),
        isSemantics(label: 'host', hasEnabledState: false),
      );
      handle.dispose();
    });

    testWidgets('us07/fr03/e02: an enabled component gets no node and no '
        'flag from the wrapper', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(
          StratumDisabled(
            disabled: false,
            child: Semantics(
              container: true,
              button: true,
              label: 'Save',
              child: _box,
            ),
          ),
        ),
      );

      expect(
        tester.getSemantics(find.byType(StratumDisabled)),
        isSemantics(label: 'host', hasEnabledState: false),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('Save')),
        isSemantics(hasEnabledState: false),
      );
      handle.dispose();
    });

    testWidgets('us07/fr03/e03: with dims off it still reads as disabled', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(
          StratumDisabled(
            disabled: true,
            dims: false,
            child: Semantics(button: true, label: 'Save', child: _box),
          ),
        ),
      );

      expect(
        tester.getSemantics(find.byType(StratumDisabled)),
        isSemantics(label: 'Save', hasEnabledState: true, isEnabled: false),
      );
      handle.dispose();
    });

    testWidgets('us07/fr03/e04: the flag stays on the component, never on '
        'the card around it', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(
          label: 'card',
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Title'),
              StratumDisabled(
                disabled: true,
                child: Semantics(button: true, label: 'Save', child: _box),
              ),
            ],
          ),
        ),
      );

      expect(
        tester.getSemantics(find.text('Title')),
        isSemantics(hasEnabledState: false),
      );
      expect(
        tester.getSemantics(find.byType(StratumDisabled)),
        isSemantics(label: 'Save', hasEnabledState: true, isEnabled: false),
      );
      handle.dispose();
    });

    testWidgets('us07/fr03: a first mount with a layer between the wrapper '
        "and the component's node is right after one pump", (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_host(_box));

      await tester.pumpWidget(
        _host(
          StratumDisabled(
            disabled: true,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Semantics(button: true, label: 'Save', child: _box),
            ),
          ),
        ),
      );

      expect(
        tester.getSemantics(find.byType(StratumDisabled)),
        isSemantics(
          label: 'Save',
          isButton: true,
          hasEnabledState: true,
          isEnabled: false,
        ),
      );
      handle.dispose();
    });

    testWidgets('us07/fr03, base s03 invariant 15: a semantics-only change '
        'under a disabled component is right after one pump', (tester) async {
      final handle = tester.ensureSemantics();
      final label = ValueNotifier<String?>(null);
      addTearDown(label.dispose);
      await tester.pumpWidget(
        _host(
          StratumDisabled(
            disabled: true,
            child: ValueListenableBuilder<String?>(
              valueListenable: label,
              builder: (_, value, _) => Semantics(label: value, child: _box),
            ),
          ),
        ),
      );

      for (final value in ['Save', null, 'Send']) {
        label.value = value;
        await tester.pump();

        final node = tester.getSemantics(find.byType(StratumDisabled));
        expect(node, isSemantics(hasEnabledState: true, isEnabled: false));
        expect(node.label, value ?? '');
      }
      handle.dispose();
    });
  });

  group('StratumDisabled structure', () {
    testWidgets('us07/fr01/e01, base s03 invariant 13: a toggle changes '
        'values only; the semantics layer, the elements, and the State '
        'stay', (tester) async {
      final handle = tester.ensureSemantics();
      Widget build({required bool disabled}) =>
          _host(StratumDisabled(disabled: disabled, child: const _Kept()));
      await tester.pumpWidget(build(disabled: false));
      final element = tester.element(find.byType(_Kept));
      final state = tester.state(find.byType(_Kept));
      final chain = _chain(tester);
      expect(chain, contains(Semantics));

      await tester.pumpWidget(build(disabled: true));
      expect(tester.element(find.byType(_Kept)), same(element));
      expect(tester.state(find.byType(_Kept)), same(state));
      expect(_chain(tester), chain);
      expect(
        tester.getSemantics(find.byType(StratumDisabled)),
        isSemantics(label: 'Save', hasEnabledState: true, isEnabled: false),
      );

      await tester.pumpWidget(build(disabled: false));
      expect(tester.element(find.byType(_Kept)), same(element));
      expect(tester.state(find.byType(_Kept)), same(state));
      expect(_chain(tester), chain);
      expect(
        tester.getSemantics(find.byType(StratumDisabled)),
        isSemantics(hasEnabledState: false),
      );
      handle.dispose();
    });
  });

  group('StratumDisabled look and input', () {
    double opacityOf(WidgetTester tester) => tester
        .widget<Opacity>(
          find
              .descendant(
                of: find.byType(StratumDisabled),
                matching: find.byType(Opacity),
              )
              .first,
        )
        .opacity;

    Future<TestGesture> hover(WidgetTester tester) async {
      final gesture = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
        pointer: 1,
      );
      await gesture.addPointer(
        location: tester.getCenter(find.byType(StratumDisabled)),
      );
      addTearDown(gesture.removePointer);
      await tester.pump();
      return gesture;
    }

    MouseCursor? cursor(WidgetTester tester) =>
        tester.binding.mouseTracker.debugDeviceActiveCursor(1);

    testWidgets('us07/fr01, us07/s1: a disabled component paints at the '
        "default theme's 0.5", (tester) async {
      await tester.pumpWidget(
        themedHost(const StratumDisabled(disabled: true, child: _box)),
      );

      expect(opacityOf(tester), 0.5);
    });

    testWidgets('us07/fr01/e02, us07/s8: a theme dimming of 0.3', (
      tester,
    ) async {
      final theme = fakeTheme.copyWith(
        opacity: StratumOpacityTokens.fromMap(const {'disabled': 0.3}),
      );
      await tester.pumpWidget(
        themedHost(
          theme: theme,
          const StratumDisabled(disabled: true, child: _box),
        ),
      );

      expect(opacityOf(tester), 0.3);
    });

    testWidgets('a theme dimming of 1 paints at full opacity', (tester) async {
      final theme = fakeTheme.copyWith(
        opacity: StratumOpacityTokens.fromMap(const {'disabled': 1.0}),
      );
      await tester.pumpWidget(
        themedHost(
          theme: theme,
          const StratumDisabled(disabled: true, child: _box),
        ),
      );

      expect(opacityOf(tester), 1.0);
    });

    testWidgets('full opacity while enabled, and while dims is off', (
      tester,
    ) async {
      await tester.pumpWidget(
        themedHost(const StratumDisabled(disabled: false, child: _box)),
      );
      expect(opacityOf(tester), 1.0);

      await tester.pumpWidget(
        themedHost(
          const StratumDisabled(disabled: true, dims: false, child: _box),
        ),
      );
      expect(opacityOf(tester), 1.0);
    });

    testWidgets('us07/fr01/e01: every layer stays across a toggle', (
      tester,
    ) async {
      Widget build({required bool disabled}) =>
          themedHost(StratumDisabled(disabled: disabled, child: const _Kept()));
      await tester.pumpWidget(build(disabled: false));
      final chain = _chain(tester);
      final state = tester.state(find.byType(_Kept));

      await tester.pumpWidget(build(disabled: true));

      expect(_chain(tester), chain);
      expect(tester.state(find.byType(_Kept)), same(state));
      expect(
        chain,
        containsAll(<Type>[
          Semantics,
          MouseRegion,
          IgnorePointer,
          ExcludeFocus,
          Opacity,
        ]),
      );
    });

    testWidgets('a widget with no theme above builds while enabled', (
      tester,
    ) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: StratumDisabled(disabled: false, child: _box),
        ),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('a theme of opacity 0 still reads as disabled', (tester) async {
      final handle = tester.ensureSemantics();
      final theme = fakeTheme.copyWith(
        opacity: StratumOpacityTokens.fromMap(const {'disabled': 0.0}),
      );
      await tester.pumpWidget(
        themedHost(
          theme: theme,
          StratumDisabled(
            disabled: true,
            child: Semantics(button: true, label: 'Save', child: _box),
          ),
        ),
      );

      expect(
        tester.getSemantics(find.byType(StratumDisabled)),
        isSemantics(label: 'Save', hasEnabledState: true, isEnabled: false),
      );
      handle.dispose();
    });

    testWidgets('us07/fr02/e02, us07/s2: a mouse over a disabled component '
        'shows the forbidden cursor and no hover look', (tester) async {
      var entered = 0;
      await tester.pumpWidget(
        themedHost(
          StratumDisabled(
            disabled: true,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              onEnter: (_) => entered++,
              child: _box,
            ),
          ),
        ),
      );
      await hover(tester);

      expect(cursor(tester), SystemMouseCursors.forbidden);
      expect(entered, 0);
    });

    testWidgets('an enabled component keeps its own cursor and hover', (
      tester,
    ) async {
      var entered = 0;
      await tester.pumpWidget(
        themedHost(
          StratumDisabled(
            disabled: false,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              onEnter: (_) => entered++,
              child: _box,
            ),
          ),
        ),
      );
      await hover(tester);

      expect(cursor(tester), SystemMouseCursors.click);
      expect(entered, 1);
    });

    testWidgets('a hovered component that turns disabled ends its hover', (
      tester,
    ) async {
      var exited = 0;
      Widget build({required bool disabled}) => themedHost(
        StratumDisabled(
          disabled: disabled,
          child: MouseRegion(onExit: (_) => exited++, child: _box),
        ),
      );
      await tester.pumpWidget(build(disabled: false));
      await hover(tester);

      await tester.pumpWidget(build(disabled: true));
      await tester.pump();

      expect(exited, 1);
      expect(cursor(tester), SystemMouseCursors.forbidden);
    });

    Widget target({
      required bool disabled,
      bool dims = true,
      required void Function() onTap,
      required void Function() onLongPress,
      required void Function() onDrag,
    }) => themedHost(
      StratumDisabled(
        disabled: disabled,
        dims: dims,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          onLongPress: onLongPress,
          onHorizontalDragUpdate: (_) => onDrag(),
          child: const SizedBox(width: 100, height: 100),
        ),
      ),
    );

    for (final dims in [true, false]) {
      testWidgets('us07/fr02/e01, us07/s11, us07/fr02/e05: a tap, a long '
          'press, or a drag runs nothing (dims $dims)', (tester) async {
        var calls = 0;
        await tester.pumpWidget(
          target(
            disabled: true,
            dims: dims,
            onTap: () => calls++,
            onLongPress: () => calls++,
            onDrag: () => calls++,
          ),
        );

        await tester.tap(find.byType(StratumDisabled), warnIfMissed: false);
        await tester.longPress(
          find.byType(StratumDisabled),
          warnIfMissed: false,
        );
        await tester.drag(
          find.byType(StratumDisabled),
          const Offset(40, 0),
          warnIfMissed: false,
        );
        await tester.pumpAndSettle();

        expect(calls, 0);
      });
    }

    testWidgets('us07/fr02: a drag in progress when it turns disabled gets '
        'no update; it ends at the flip, as a cancelled drag does', (
      tester,
    ) async {
      final log = <String>[];
      Widget build({required bool disabled}) => themedHost(
        StratumDisabled(
          disabled: disabled,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragUpdate: (_) => log.add('update'),
            onHorizontalDragEnd: (_) => log.add('end'),
            child: const SizedBox(width: 100, height: 100),
          ),
        ),
      );
      await tester.pumpWidget(build(disabled: false));
      final drag = await tester.startGesture(
        tester.getCenter(find.byType(StratumDisabled)),
      );
      await drag.moveBy(const Offset(30, 0));
      await drag.moveBy(const Offset(10, 0));
      expect(log, contains('update'));
      log.clear();

      await tester.pumpWidget(build(disabled: true));
      expect(log, ['end']);

      await drag.moveBy(const Offset(10, 0));
      await drag.up();
      await tester.pump();
      expect(log, ['end']);
    });

    testWidgets('us07/fr02: a press in progress when it turns disabled runs '
        'no tap on release', (tester) async {
      var taps = 0;
      var cancels = 0;
      Widget build({required bool disabled}) => themedHost(
        StratumDisabled(
          disabled: disabled,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => taps++,
            onTapCancel: () => cancels++,
            child: const SizedBox(width: 100, height: 100),
          ),
        ),
      );
      await tester.pumpWidget(build(disabled: false));
      final press = await tester.startGesture(
        tester.getCenter(find.byType(StratumDisabled)),
      );
      await tester.pump(kPressTimeout);

      await tester.pumpWidget(build(disabled: true));
      await press.up();
      await tester.pump(kDoubleTapTimeout);

      expect(taps, 0);
      expect(cancels, 1);
    });

    testWidgets('us07/fr02/e06: enabled again, it takes taps', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        target(
          disabled: true,
          onTap: () => taps++,
          onLongPress: () {},
          onDrag: () {},
        ),
      );
      await tester.pumpWidget(
        target(
          disabled: false,
          onTap: () => taps++,
          onLongPress: () {},
          onDrag: () {},
        ),
      );

      await tester.tap(find.byType(StratumDisabled));
      await tester.pump(kDoubleTapTimeout);

      expect(taps, 1);
    });

    Widget form(
      FocusNode first,
      FocusNode inner,
      FocusNode third, {
      required bool disabled,
      bool dims = true,
    }) => themedHost(
      Shortcuts(
        shortcuts: WidgetsApp.defaultShortcuts,
        child: Actions(
          actions: WidgetsApp.defaultActions,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Focus(focusNode: first, child: _box),
              StratumDisabled(
                disabled: disabled,
                dims: dims,
                child: Focus(focusNode: inner, child: _box),
              ),
              Focus(focusNode: third, child: _box),
            ],
          ),
        ),
      ),
    );

    for (final dims in [true, false]) {
      testWidgets('us07/fr02/e03, us07/s3, us07/fr02/e05: Tab passes over a '
          'disabled component (dims $dims)', (tester) async {
        final first = FocusNode(debugLabel: 'first');
        final inner = FocusNode(debugLabel: 'inner');
        final third = FocusNode(debugLabel: 'third');
        addTearDown(first.dispose);
        addTearDown(inner.dispose);
        addTearDown(third.dispose);
        await tester.pumpWidget(
          form(first, inner, third, disabled: true, dims: dims),
        );
        first.requestFocus();
        await tester.pump();

        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();

        expect(third.hasPrimaryFocus, isTrue);
        expect(inner.hasFocus, isFalse);
      });
    }

    testWidgets('us07/fr02/e04, us07/s4: a focused component that turns '
        'disabled loses focus; us07/fr02/e06: enabled, it is a Tab stop '
        'again', (tester) async {
      final first = FocusNode(debugLabel: 'first');
      final inner = FocusNode(debugLabel: 'inner');
      final third = FocusNode(debugLabel: 'third');
      addTearDown(first.dispose);
      addTearDown(inner.dispose);
      addTearDown(third.dispose);
      await tester.pumpWidget(form(first, inner, third, disabled: false));
      inner.requestFocus();
      await tester.pump();
      expect(inner.hasPrimaryFocus, isTrue);

      await tester.pumpWidget(form(first, inner, third, disabled: true));
      await tester.pump();
      expect(inner.hasFocus, isFalse);

      await tester.pumpWidget(form(first, inner, third, disabled: false));
      first.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(inner.hasPrimaryFocus, isTrue);
    });
  });
}
