import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui_test_app/fixture_route.dart';

void main() {
  group('fixtureRoutePrefix', () {
    test('is /fixture/', () {
      expect(fixtureRoutePrefix, '/fixture/');
    });
  });

  group('fixtureIdFrom', () {
    test('returns the id after the prefix of a --route argument', () {
      expect(
        fixtureIdFrom(
          args: const ['--route=/fixture/smoke/semantics_id'],
          defaultRouteName: '/',
        ),
        'smoke/semantics_id',
      );
    });

    test('falls back to the default route name', () {
      expect(
        fixtureIdFrom(
          args: const [],
          defaultRouteName: '/fixture/common/web_view',
        ),
        'common/web_view',
      );
    });

    test('returns null when the default route has no prefix', () {
      expect(fixtureIdFrom(args: const [], defaultRouteName: '/'), isNull);
    });

    test('an argument wins over the default route name', () {
      expect(
        fixtureIdFrom(
          args: const ['--route=/fixture/smoke/semantics_id'],
          defaultRouteName: '/fixture/common/web_view',
        ),
        'smoke/semantics_id',
      );
    });

    test('returns null for a --route argument without the prefix', () {
      expect(
        fixtureIdFrom(args: const ['--route=/x'], defaultRouteName: '/'),
        isNull,
      );
    });

    test('a present argument always wins, even without the prefix', () {
      expect(
        fixtureIdFrom(
          args: const ['--route=/x'],
          defaultRouteName: '/fixture/a/b',
        ),
        isNull,
      );
    });
  });
}
