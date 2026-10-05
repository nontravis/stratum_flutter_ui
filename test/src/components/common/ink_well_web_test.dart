@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';

import 'fakes/web_themed_host.dart';

const _box = SizedBox(width: 40, height: 20);

void _noop() {}

class _Keep extends StatefulWidget {
  const new({this.focusNode});

  final FocusNode? focusNode;

  @override
  State<_Keep> createState() => _KeepState();
}

class _KeepState extends State<_Keep> {
  late final FocusNode _node = FocusNode(debugLabel: '_Keep');

  @override
  void dispose() {
    _node.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      Focus(focusNode: widget.focusNode ?? _node, child: _box);
}

/// The one child node of [node]; fails when it has none or several.
SemanticsNode _onlyChild(SemanticsNode node) {
  final children = <SemanticsNode>[];
  node.visitChildren((child) {
    children.add(child);
    return true;
  });
  expect(children, hasLength(1));
  return children.single;
}

/// The heading level of the semantics node at [finder].
int _levelOf(WidgetTester tester, Finder finder) =>
    tester.getSemantics(finder).getSemanticsData().headingLevel;

void main() {
  group('us04/fr02, s03/inv8: StratumInkWell web semantics', () {
    testWidgets(
      'us04/fr02: an activation callback gives one button node on web',
      (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          webThemedHost(
            const StratumInkWell(
              onTap: _noop,
              semantics: SemanticsProperties(label: 'Open settings'),
              child: _box,
            ),
          ),
        );

        final node = tester.getSemantics(find.byType(StratumInkWell));
        expect(node.getSemanticsData().headingLevel, 0);
        expect(node.childrenCount, 0);
        expect(
          node,
          isSemantics(
            label: 'Open settings',
            isButton: true,
            hasEnabledState: true,
            isEnabled: true,
            hasTapAction: true,
          ),
        );
        handle.dispose();
      },
    );

    testWidgets(
      'us04/fr02/e07: a header button reads as a level 2 heading that '
      'holds the button',
      (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          webThemedHost(
            const StratumInkWell(
              onTap: _noop,
              onSecondaryTap: _noop,
              semantics: SemanticsProperties(header: true, label: 'Recent'),
              child: _box,
            ),
          ),
        );

        final heading = tester.getSemantics(find.byType(StratumInkWell));
        expect(heading.getSemanticsData().headingLevel, 2);
        expect(
          heading,
          isSemantics(
            label: '',
            isHeader: false,
            isButton: false,
            hasTapAction: false,
          ),
        );
        final button = _onlyChild(heading);
        expect(button.getSemanticsData().headingLevel, 0);
        expect(
          button,
          isSemantics(
            label: 'Recent',
            isHeader: false,
            isButton: true,
            hasEnabledState: true,
            isEnabled: true,
            isFocusable: true,
            hasTapAction: true,
            customActions: [const CustomSemanticsAction(label: 'Show menu')],
          ),
        );
        handle.dispose();
      },
    );

    testWidgets(
      'us04/fr02/e07: a caller button true splits without a callback',
      (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          webThemedHost(
            const StratumInkWell(
              semantics: SemanticsProperties(
                button: true,
                header: true,
                label: 'Recent',
              ),
              child: _box,
            ),
          ),
        );

        final heading = tester.getSemantics(find.byType(StratumInkWell));
        expect(heading.getSemanticsData().headingLevel, 2);
        expect(
          _onlyChild(heading),
          isSemantics(label: 'Recent', isHeader: false, isButton: true),
        );
        handle.dispose();
      },
    );

    testWidgets('us04/fr02/e09: a headingLevel sets the heading level', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        webThemedHost(
          const StratumInkWell(
            onTap: _noop,
            semantics: SemanticsProperties(headingLevel: 4, label: 'Recent'),
            child: _box,
          ),
        ),
      );

      final heading = tester.getSemantics(find.byType(StratumInkWell));
      expect(heading.getSemanticsData().headingLevel, 4);
      final button = _onlyChild(heading);
      expect(button.getSemanticsData().headingLevel, 0);
      expect(
        button,
        isSemantics(label: 'Recent', isButton: true, hasTapAction: true),
      );
      handle.dispose();
    });

    testWidgets('us04/fr02/e07: a right-to-left header button splits like '
        'left-to-right', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        webThemedHost(
          const StratumInkWell(
            onTap: _noop,
            semantics: SemanticsProperties(header: true, label: 'Recent'),
            child: _box,
          ),
          textDirection: TextDirection.rtl,
        ),
      );

      final heading = tester.getSemantics(find.byType(StratumInkWell));
      expect(heading.getSemanticsData().headingLevel, 2);
      expect(
        heading,
        isSemantics(
          label: '',
          isHeader: false,
          isButton: false,
          hasTapAction: false,
        ),
      );
      final button = _onlyChild(heading);
      expect(button.getSemanticsData().headingLevel, 0);
      expect(
        button,
        isSemantics(
          label: 'Recent',
          isHeader: false,
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          isFocusable: true,
          hasTapAction: true,
        ),
      );
      handle.dispose();
    });

    testWidgets(
      'us04/fr02/e05: a disabled header button is a dimmed button in the '
      'heading',
      (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          webThemedHost(
            const StratumInkWell(
              onTap: _noop,
              disabled: true,
              semantics: SemanticsProperties(header: true, label: 'Recent'),
              child: _box,
            ),
          ),
        );

        final heading = tester.getSemantics(find.byType(StratumInkWell));
        expect(heading.getSemanticsData().headingLevel, 2);
        expect(
          _onlyChild(heading),
          isSemantics(
            label: 'Recent',
            isButton: true,
            hasEnabledState: true,
            isEnabled: false,
            hasTapAction: false,
          ),
        );
        handle.dispose();
      },
    );

    testWidgets('us04/fr02/e07: a caller enabled false keeps the heading and a '
        'disabled button', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        webThemedHost(
          const StratumInkWell(
            onTap: _noop,
            semantics: SemanticsProperties(
              enabled: false,
              header: true,
              label: 'Recent',
            ),
            child: _box,
          ),
        ),
      );

      final heading = tester.getSemantics(find.byType(StratumInkWell));
      expect(heading.getSemanticsData().headingLevel, 2);
      expect(
        _onlyChild(heading),
        isSemantics(
          label: 'Recent',
          isButton: true,
          hasEnabledState: true,
          isEnabled: false,
          hasTapAction: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('us04/fr02/e01: a link header stays one node', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        webThemedHost(
          const StratumInkWell(
            onTap: _noop,
            semantics: SemanticsProperties(
              link: true,
              header: true,
              label: 'Docs',
            ),
            child: _box,
          ),
        ),
      );

      final node = tester.getSemantics(find.byType(StratumInkWell));
      expect(node.getSemanticsData().headingLevel, 0);
      expect(node.childrenCount, 0);
      expect(
        node,
        isSemantics(
          label: 'Docs',
          isLink: true,
          isHeader: true,
          isButton: false,
        ),
      );
      handle.dispose();
    });

    testWidgets('us04/fr02/e03: excludeFromSemantics builds no heading node', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      const key = Key('host');
      await tester.pumpWidget(
        webThemedHost(
          Semantics(
            key: key,
            container: true,
            child: const StratumInkWell(
              onTap: _noop,
              excludeFromSemantics: true,
              semantics: SemanticsProperties(header: true, label: 'Recent'),
              child: _box,
            ),
          ),
        ),
      );

      final node = tester.getSemantics(find.byKey(key));
      expect(node.getSemanticsData().headingLevel, 0);
      expect(node.childrenCount, 0);
      expect(
        node,
        isSemantics(label: 'Recent', isHeader: true, isButton: false),
      );
      handle.dispose();
    });

    testWidgets(
      'us04/fr02/e07: a box layout passes a header to the tap surface',
      (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          webThemedHost(
            const ContainerLayout(
              interaction: StratumInteraction(onTap: _noop),
              semantics: SemanticsProperties(header: true, label: 'Recent'),
              child: _box,
            ),
          ),
        );

        final heading = tester.getSemantics(find.byType(StratumInkWell));
        expect(heading.getSemanticsData().headingLevel, 2);
        expect(
          _onlyChild(heading),
          isSemantics(label: 'Recent', isHeader: false, isButton: true),
        );
        handle.dispose();
      },
    );

    testWidgets(
      'us04/fr02/e07: a header button inside a header button splits at each '
      'surface',
      (tester) async {
        final handle = tester.ensureSemantics();
        const outerKey = Key('outer');
        const innerKey = Key('inner');
        await tester.pumpWidget(
          webThemedHost(
            const StratumInkWell(
              key: outerKey,
              onTap: _noop,
              semantics: SemanticsProperties(header: true),
              child: StratumInkWell(
                key: innerKey,
                onTap: _noop,
                semantics: SemanticsProperties(
                  headingLevel: 3,
                  label: 'Recent',
                ),
                child: _box,
              ),
            ),
          ),
        );

        final outerHeading = tester.getSemantics(find.byKey(outerKey));
        expect(outerHeading.getSemanticsData().headingLevel, 2);
        expect(
          outerHeading,
          isSemantics(
            label: '',
            isHeader: false,
            isButton: false,
            hasTapAction: false,
          ),
        );
        final outerButton = _onlyChild(outerHeading);
        expect(outerButton.getSemanticsData().headingLevel, 0);
        expect(
          outerButton,
          isSemantics(
            label: '',
            isHeader: false,
            isButton: true,
            hasTapAction: true,
          ),
        );
        final innerHeading = _onlyChild(outerButton);
        expect(innerHeading.getSemanticsData().headingLevel, 3);
        final innerButton = _onlyChild(innerHeading);
        expect(innerButton.getSemanticsData().headingLevel, 0);
        expect(
          innerButton,
          isSemantics(
            label: 'Recent',
            isHeader: false,
            isButton: true,
            hasEnabledState: true,
            isEnabled: true,
            hasTapAction: true,
          ),
        );
        handle.dispose();
      },
    );

    testWidgets(
      'us04/fr02/e07: adding a header and changing its level keeps the '
      'child State',
      (tester) async {
        final handle = tester.ensureSemantics();
        final keepFocus = FocusNode(debugLabel: '_Keep');
        addTearDown(keepFocus.dispose);
        Widget build(SemanticsProperties semantics) => webThemedHost(
          StratumInkWell(
            onTap: _noop,
            semantics: semantics,
            child: _Keep(focusNode: keepFocus),
          ),
        );

        await tester.pumpWidget(
          build(const SemanticsProperties(label: 'Recent')),
        );
        final before = tester.state(find.byType(_Keep));
        keepFocus.requestFocus();
        await tester.pump();
        expect(FocusManager.instance.primaryFocus, same(keepFocus));

        await tester.pumpWidget(
          build(const SemanticsProperties(header: true, label: 'Recent')),
        );
        expect(tester.state(find.byType(_Keep)), same(before));
        expect(FocusManager.instance.primaryFocus, same(keepFocus));
        expect(_levelOf(tester, find.byType(StratumInkWell)), 2);

        await tester.pumpWidget(
          build(const SemanticsProperties(headingLevel: 4, label: 'Recent')),
        );
        expect(tester.state(find.byType(_Keep)), same(before));
        expect(FocusManager.instance.primaryFocus, same(keepFocus));
        expect(_levelOf(tester, find.byType(StratumInkWell)), 4);
        handle.dispose();
      },
    );
  });
}
