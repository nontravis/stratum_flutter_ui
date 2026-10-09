import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/components/common/base/disabled.dart';
import 'package:stratum_ui/src/src.dart';

import '../fakes/fake_stratum_theme.dart';

const _box = SizedBox(width: 40, height: 20);

/// [child] inside a host node labelled [label], so a test can tell whether
/// [child] formed a node of its own.
Widget _host(Widget child, {String label = 'host'}) =>
    themedHost(Semantics(container: true, label: label, child: child));

/// A widget with a State of its own, for the structure checks.
class _Kept extends StatefulWidget {
  const new();

  @override
  State<_Kept> createState() => _KeptState();
}

class _KeptState extends State<_Kept> {
  @override
  Widget build(BuildContext context) => _box;
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
    testWidgets('us07/fr03, us07/s5: a disabled component that contributes '
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

    testWidgets('us07/fr03/e01, us07/s6: a disabled subtree with no '
        'semantics adds no node and no flag', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(const StratumDisabled(disabled: true, child: _box)),
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

    testWidgets('us07/fr03: a disabled subtree that gains semantics later '
        'reads as disabled', (tester) async {
      final handle = tester.ensureSemantics();
      Widget build({required bool labelled}) => _host(
        StratumDisabled(
          disabled: true,
          child: Semantics(label: labelled ? 'Save' : null, child: _box),
        ),
      );
      await tester.pumpWidget(build(labelled: false));
      expect(
        tester.getSemantics(find.byType(StratumDisabled)),
        isSemantics(label: 'host', hasEnabledState: false),
      );

      await tester.pumpWidget(build(labelled: true));
      await tester.pump();

      expect(
        tester.getSemantics(find.byType(StratumDisabled)),
        isSemantics(label: 'Save', hasEnabledState: true, isEnabled: false),
      );
      handle.dispose();
    });
  });

  group('StratumDisabled structure', () {
    testWidgets('us07/fr01/e01: a toggle changes values only; the subtree '
        'keeps its elements and its State', (tester) async {
      final handle = tester.ensureSemantics();
      Widget build({required bool disabled}) => _host(
        StratumDisabled(
          disabled: disabled,
          child: Semantics(button: true, label: 'Save', child: const _Kept()),
        ),
      );
      await tester.pumpWidget(build(disabled: false));
      final element = tester.element(find.byType(_Kept));
      final state = tester.state(find.byType(_Kept));
      final chain = _chain(tester);

      await tester.pumpWidget(build(disabled: true));
      expect(tester.element(find.byType(_Kept)), same(element));
      expect(tester.state(find.byType(_Kept)), same(state));
      expect(_chain(tester), chain);
      expect(
        tester.getSemantics(find.byType(StratumDisabled)),
        isSemantics(hasEnabledState: true, isEnabled: false),
      );

      await tester.pumpWidget(build(disabled: false));
      expect(tester.state(find.byType(_Kept)), same(state));
      expect(_chain(tester), chain);
      expect(
        tester.getSemantics(find.byType(StratumDisabled)),
        isSemantics(hasEnabledState: false),
      );
      handle.dispose();
    });
  });
}
