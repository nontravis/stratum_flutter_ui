import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/components/common/layout/page_areas.dart';
import 'package:stratum_ui/src/components/common/model/page_layout/page_areas.dart';
import 'package:stratum_ui/src/src.dart';

// The registry primitives M4-T27 built, unit-tested directly (Edge Minor
// finding 7): a page's handle, the probe that keeps it on or off stage,
// the controller that picks the innermost on-stage one (N14), and the
// render-level reporter's detach/reattach and move-without-layout paths,
// each reached only indirectly through `toast_page_test.dart` before this
// file.

void main() {
  group('PageAreas', () {
    test('us18/fr01: has value equality and copyWith', () {
      // Built at run time from a parameter, so no const canonicalization
      // makes them one instance and the check reads `==`, not identity.
      PageAreas make(double footerTop) => PageAreas(
        body: const Rect.fromLTWH(0, 0, 10, 10),
        footerTop: footerTop,
      );
      final a = make(5);
      final b = make(5);
      expect(identical(a, b), isFalse);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      final c = a.copyWith(footerTop: 9);
      expect(c.footerTop, 9);
      expect(c.body, a.body);
    });
  });

  group('PageAreasHandle', () {
    test('detach is a no-op once the value is already null', () {
      final handle = PageAreasHandle();
      addTearDown(handle.dispose);
      var notified = 0;
      handle
        ..addListener(() => notified++)
        ..detach();
      expect(handle.value, isNull);
      expect(notified, 0);
    });

    test('detach quiets the notification and zeros a set value', () {
      final handle = PageAreasHandle();
      addTearDown(handle.dispose);
      handle.value = const PageAreas(footerTop: 10);
      var notified = 0;
      handle
        ..addListener(() => notified++)
        ..detach();
      expect(handle.value, isNull);
      expect(notified, 0);
    });

    test('a handle with no mounted probe is never current', () {
      final handle = PageAreasHandle();
      addTearDown(handle.dispose);
      expect(handle.isCurrent, isFalse);
    });
  });

  group('PageAreasProbe', () {
    testWidgets('puts its handle on stage while the route is current and '
        'takes it off once the probe unmounts', (tester) async {
      final handle = PageAreasHandle();
      addTearDown(handle.dispose);
      late StateSetter setMounted;
      var mounted = true;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              setMounted = setState;
              return mounted
                  ? PageAreasProbe(handle: handle, child: const SizedBox())
                  : const SizedBox();
            },
          ),
        ),
      );
      expect(handle.isCurrent, isTrue);
      setMounted(() => mounted = false);
      await tester.pump();
      expect(handle.isCurrent, isFalse);
    });

    testWidgets('a covered route takes the handle off stage, and the pop '
        'puts it back, notifying after each frame', (tester) async {
      final handle = PageAreasHandle();
      addTearDown(handle.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: PageAreasProbe(handle: handle, child: const SizedBox()),
        ),
      );
      var notified = 0;
      handle.addListener(() => notified++);
      final navigator = tester.state<NavigatorState>(find.byType(Navigator))
        ..push(MaterialPageRoute<void>(builder: (_) => const Text('x')));
      await tester.pumpAndSettle();
      expect(handle.isCurrent, isFalse);
      expect(notified, 1);
      navigator.pop();
      await tester.pumpAndSettle();
      expect(handle.isCurrent, isTrue);
      expect(notified, 2);
    });

    for (final (name, hide) in [
      (
        'TickerMode(enabled: false)',
        (Widget child) => TickerMode(enabled: false, child: child),
      ),
      (
        'Visibility.maintain(visible: false)',
        (Widget child) => Visibility.maintain(visible: false, child: child),
      ),
    ]) {
      testWidgets('a probe under $name keeps its handle off stage on a '
          'current route', (tester) async {
        final handle = PageAreasHandle();
        addTearDown(handle.dispose);
        await tester.pumpWidget(
          MaterialApp(
            home: hide(PageAreasProbe(handle: handle, child: const SizedBox())),
          ),
        );
        expect(handle.isCurrent, isFalse);
      });
    }

    testWidgets('a flip rebuilds the probe alone, never the page below it', (
      tester,
    ) async {
      final handle = PageAreasHandle();
      addTearDown(handle.dispose);
      final ticking = ValueNotifier(true);
      addTearDown(ticking.dispose);
      var pageBuilds = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: ValueListenableBuilder<bool>(
            valueListenable: ticking,
            builder: (context, enabled, child) =>
                TickerMode(enabled: enabled, child: child!),
            child: PageAreasProbe(
              handle: handle,
              child: Builder(
                builder: (_) {
                  pageBuilds++;
                  return const SizedBox();
                },
              ),
            ),
          ),
        ),
      );
      pageBuilds = 0;
      ticking.value = false;
      await tester.pump();
      expect(handle.isCurrent, isFalse);
      expect(pageBuilds, 0);
    });
  });

  group('PageAreasController', () {
    test('remove is a no-op for a handle never added', () {
      final controller = PageAreasController();
      addTearDown(controller.dispose);
      final handle = PageAreasHandle();
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
      final handle = PageAreasHandle();
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
      final outerHandle = PageAreasHandle();
      final innerHandle = PageAreasHandle();
      addTearDown(outerHandle.dispose);
      addTearDown(innerHandle.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: PageAreasProbe(
            handle: outerHandle,
            child: PageAreasProbe(handle: innerHandle, child: const SizedBox()),
          ),
        ),
      );
      final controller = PageAreasController();
      addTearDown(controller.dispose);
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
      final handle1 = PageAreasHandle();
      final handle2 = PageAreasHandle();
      addTearDown(handle1.dispose);
      addTearDown(handle2.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Row(
            children: [
              PageAreasProbe(handle: handle1, child: const SizedBox()),
              PageAreasProbe(handle: handle2, child: const SizedBox()),
            ],
          ),
        ),
      );
      final controller = PageAreasController();
      addTearDown(controller.dispose);
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

    testWidgets('current() skips a later-added handle whose branch is '
        'hidden (edge I6)', (tester) async {
      final shown = PageAreasHandle();
      final hidden = PageAreasHandle();
      addTearDown(shown.dispose);
      addTearDown(hidden.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: IndexedStack(
            children: [
              PageAreasProbe(handle: shown, child: const SizedBox()),
              PageAreasProbe(handle: hidden, child: const SizedBox()),
            ],
          ),
        ),
      );
      final controller = PageAreasController();
      addTearDown(controller.dispose);
      controller
        ..add(shown)
        ..add(hidden);
      expect(controller.current(), same(shown));
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

    testWidgets('reports a move its parent makes with no layout of the '
        'reporter itself (correctness footerTop)', (tester) async {
      final reports = <Rect>[];
      late StateSetter setState;
      var alignment = Alignment.topLeft;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setter) {
              setState = setter;
              // The same loose constraints in both positions, so the
              // reporter is never laid out again; only its offset moves.
              return Align(
                alignment: alignment,
                child: PageAreasReporter(
                  report: reports.add,
                  child: const SizedBox(width: 10, height: 10),
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      reports.clear();
      setState(() => alignment = Alignment.bottomRight);
      await tester.pumpAndSettle();
      expect(reports, isNotEmpty);
      expect(reports.last, tester.getRect(find.byType(PageAreasReporter)));
    });
  });
}
