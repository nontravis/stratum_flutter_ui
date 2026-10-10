@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/stratum_ui.dart';

void main() {
  test('D6: the three stubs are gone and unexported', () {
    const deletedPaths = [
      'lib/src/components/common/in_app_update.dart',
      'lib/src/components/common/utility/todo.dart',
      'lib/src/components/common/page/page.dart',
    ];
    for (final path in deletedPaths) {
      expect(File(path).existsSync(), isFalse, reason: path);
    }

    final common = File(
      'lib/src/components/common/common.dart',
    ).readAsStringSync();
    final utility = File(
      'lib/src/components/common/utility/utility.dart',
    ).readAsStringSync();
    expect(common, isNot(contains('in_app_update.dart')));
    expect(common, isNot(contains('page/page.dart')));
    expect(utility, isNot(contains('todo.dart')));
  });

  test('the package exports StratumShow and StratumWebZoom', () {
    expect(
      const StratumShow(visible: true, child: SizedBox()),
      isA<StatefulWidget>(),
    );
    expect(StratumShowTransition.values, hasLength(4));
    expect(StratumShowSlideDirection.values, hasLength(4));
    expect(const StratumWebZoom(child: SizedBox()), isA<StatelessWidget>());
  });
}
