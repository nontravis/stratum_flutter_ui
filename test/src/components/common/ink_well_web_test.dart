@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';

import 'fakes/web_themed_host.dart';

const _box = SizedBox(width: 40, height: 20);

void _noop() {}

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
  });
}
