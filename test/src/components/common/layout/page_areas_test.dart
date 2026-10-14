import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/components/common/layout/page_areas.dart';
import 'package:stratum_ui/src/src.dart';

// The registry primitives M4-T27 built, unit-tested directly (Edge Minor
// finding 7): a page's handle, the controller that picks the innermost
// current one (N14), and the render-level reporter's detach/reattach
// path, each reached only indirectly through `toast_page_test.dart`
// before this file.

void main() {
  group('PageAreasHandle', () {
    test('detach is a no-op once the value is already null', () {
      final handle = PageAreasHandle(
        isCurrentRoute: () => true,
        context: () => throw UnimplementedError('unused by this case'),
      );
      addTearDown(handle.dispose);
      var notified = 0;
      handle
        ..addListener(() => notified++)
        ..detach();
      expect(handle.value, isNull);
      expect(notified, 0);
    });

    test('detach quiets the notification and zeros a set value', () {
      final handle = PageAreasHandle(
        isCurrentRoute: () => true,
        context: () => throw UnimplementedError('unused by this case'),
      );
      addTearDown(handle.dispose);
      handle.value = const PageAreas(footerTop: 10);
      var notified = 0;
      handle
        ..addListener(() => notified++)
        ..detach();
      expect(handle.value, isNull);
      expect(notified, 0);
    });
  });

  group('PageAreasController', () {
    test('remove is a no-op for a handle never added', () {
      final controller = PageAreasController();
      addTearDown(controller.dispose);
      final handle = PageAreasHandle(
        isCurrentRoute: () => true,
        context: () => throw UnimplementedError('unused by this case'),
      );
      addTearDown(handle.dispose);
      final versions = <int>[];
      controller.version.addListener(
        () => versions.add(controller.version.value),
      );
      controller.remove(handle);
      expect(versions, isEmpty);
    });

    test('add then remove each bump the version once', () {
      final controller = PageAreasController();
      addTearDown(controller.dispose);
      final handle = PageAreasHandle(
        isCurrentRoute: () => true,
        context: () => throw UnimplementedError('unused by this case'),
      );
      addTearDown(handle.dispose);
      var bumps = 0;
      controller.version.addListener(() => bumps++);
      controller.add(handle);
      expect(bumps, 1);
      controller.remove(handle);
      expect(bumps, 2);
    });

    testWidgets('current() picks the handle nested inside the other candidate, '
        'never the one that merely registered last (N14)', (tester) async {
      final outerKey = GlobalKey();
      final innerKey = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            key: outerKey,
            child: SizedBox(key: innerKey, child: const SizedBox()),
          ),
        ),
      );
      final outerContext = tester.element(find.byKey(outerKey));
      final innerContext = tester.element(find.byKey(innerKey));
      final controller = PageAreasController();
      addTearDown(controller.dispose);
      final outerHandle = PageAreasHandle(
        isCurrentRoute: () => true,
        context: () => outerContext,
      );
      final innerHandle = PageAreasHandle(
        isCurrentRoute: () => true,
        context: () => innerContext,
      );
      addTearDown(outerHandle.dispose);
      addTearDown(innerHandle.dispose);
      // Registered out of nesting order: the inner page joins first,
      // the outer second — pure add-order would then (wrongly) read
      // the outer page as "innermost".
      controller
        ..add(innerHandle)
        ..add(outerHandle);
      expect(controller.current(), same(innerHandle));
    });

    testWidgets('current() falls back to the most recently added handle when '
        'neither candidate nests inside the other, in either order', (
      tester,
    ) async {
      final key1 = GlobalKey();
      final key2 = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          home: Row(
            children: [
              SizedBox(key: key1),
              SizedBox(key: key2),
            ],
          ),
        ),
      );
      final context1 = tester.element(find.byKey(key1));
      final context2 = tester.element(find.byKey(key2));
      final controller = PageAreasController();
      addTearDown(controller.dispose);
      final handle1 = PageAreasHandle(
        isCurrentRoute: () => true,
        context: () => context1,
      );
      final handle2 = PageAreasHandle(
        isCurrentRoute: () => true,
        context: () => context2,
      );
      addTearDown(handle1.dispose);
      addTearDown(handle2.dispose);
      controller
        ..add(handle1)
        ..add(handle2);
      expect(controller.current(), same(handle2));
      controller
        ..remove(handle1)
        ..remove(handle2)
        ..add(handle2)
        ..add(handle1);
      expect(controller.current(), same(handle1));
    });
  });

  group('PageAreasReporter', () {
    testWidgets(
      'reports again once the render object reattaches at a new parent, '
      'surviving the detach without the owning State disposing',
      (tester) async {
        final key = GlobalKey();
        final reports = <Rect>[];
        late StateSetter setState;
        var underCenter = true;
        Widget reporter() => PageAreasReporter(
          key: key,
          report: reports.add,
          child: const SizedBox(width: 10, height: 10),
        );
        await tester.pumpWidget(
          MaterialApp(
            home: StatefulBuilder(
              builder: (context, setter) {
                setState = setter;
                // Two different parent widget *types* at the same tree
                // position: Flutter's GlobalKey reservation moves the
                // keyed Element (and its RenderObject) from the old
                // parent to the new one, rather than rebuilding it in
                // place — the actual detach-then-attach this proves
                // against (a reporter recycled inside a scrolling list
                // hits the same path).
                return underCenter
                    ? Center(child: reporter())
                    : Padding(
                        padding: const EdgeInsets.all(40),
                        child: reporter(),
                      );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        reports.clear();
        setState(() => underCenter = false);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(reports, isNotEmpty);
      },
    );
  });
}
