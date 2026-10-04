// ignore_for_file: implementation_imports
import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';

import '../../integration_test/baseline/baseline.dart';
import '../../integration_test/perf/perf_host.dart';
import '../../integration_test/perf/perf_kit.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadPerfTheme);

  void onTap() {}

  group('CurrentKit', () {
    test('passes the tap to RowLayout through its interaction', () {
      final row = const CurrentKit().row(
        onTap: onTap,
        mainAxisAlignment: MainAxisAlignment.end,
        children: const [],
      );
      expect(
        row,
        isA<RowLayout>()
            .having((r) => r.interaction?.onTap, 'interaction.onTap', onTap)
            .having(
              (r) => r.mainAxisAlignment,
              'mainAxisAlignment',
              MainAxisAlignment.end,
            ),
      );
    });

    test('builds a RowLayout without interaction when there is no tap', () {
      final row = const CurrentKit().row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: const [],
      );
      expect(
        row,
        isA<RowLayout>().having((r) => r.interaction, 'interaction', isNull),
      );
    });

    testWidgets('an intrinsic column builds the live FlexLayout and sizes '
        'its buttons to the widest one', (tester) async {
      await tester.pumpWidget(
        perfHost(
          const CurrentKit().column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            crossAxisIntrinsic: true,
            children: const [
              SizedBox(key: Key('narrow'), width: 10, height: 10),
              SizedBox(key: Key('wide'), width: 30, height: 10),
            ],
          ),
        ),
      );

      expect(tester.widget(find.byType(ColumnLayout)), isA<FlexLayout>());
      expect(tester.getSize(find.byKey(const Key('narrow'))).width, 30);
      expect(tester.getSize(find.byType(ColumnLayout)).width, 30);
    });
  });

  group('BaselineKit', () {
    test('builds BaselineRowLayout without interaction when there is no '
        'tap', () {
      final row = const BaselineKit().row(
        style: const WidgetStyle(),
        mainAxisAlignment: MainAxisAlignment.end,
        children: const [],
      );
      expect(
        row,
        isA<BaselineRowLayout>()
            .having(
              (r) => r.mainAxisAlignment,
              'mainAxisAlignment',
              MainAxisAlignment.end,
            )
            .having((r) => r.interaction, 'interaction', isNull),
      );
    });

    test('passes the tap to BaselineRowLayout through its interaction', () {
      final row = const BaselineKit().row(
        onTap: onTap,
        mainAxisAlignment: MainAxisAlignment.start,
        children: const [],
      );
      expect(
        row,
        isA<BaselineRowLayout>().having(
          (r) => r.interaction,
          'interaction',
          isA<StratumInteraction>().having((i) => i.onTap, 'onTap', onTap),
        ),
      );
    });

    test('builds BaselineColumnLayout and BaselineContainerLayout', () {
      const kit = BaselineKit();
      expect(
        kit.column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: const [],
        ),
        isA<BaselineColumnLayout>()
            .having((c) => c.mainAxisSize, 'mainAxisSize', MainAxisSize.min)
            .having(
              (c) => c.crossAxisAlignment,
              'crossAxisAlignment',
              CrossAxisAlignment.end,
            ),
      );
      expect(
        kit.container(style: const WidgetStyle(width: 4)),
        isA<BaselineContainerLayout>().having(
          (c) => c.style,
          'style',
          const WidgetStyle(width: 4),
        ),
      );
    });

    testWidgets('a tappable row runs the frozen FlexLayout and the frozen '
        'tap surface', (tester) async {
      await tester.pumpWidget(
        perfHost(
          const BaselineKit().row(
            style: const WidgetStyle(),
            onTap: onTap,
            mainAxisAlignment: MainAxisAlignment.start,
            children: const [SizedBox(width: 10, height: 10)],
          ),
        ),
      );

      expect(
        tester.widget(find.byType(BaselineRowLayout)),
        isA<BaselineFlexLayout>(),
      );
      expect(find.byType(BaselineStratumInkWell), findsOneWidget);
      expect(find.byType(StratumInkWell), findsNothing);
    });

    testWidgets('an intrinsic column builds the frozen FlexLayout and '
        'sizes its buttons to the widest one', (tester) async {
      await tester.pumpWidget(
        perfHost(
          const BaselineKit().column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            crossAxisIntrinsic: true,
            children: const [
              SizedBox(key: Key('narrow'), width: 10, height: 10),
              SizedBox(key: Key('wide'), width: 30, height: 10),
            ],
          ),
        ),
      );

      expect(
        tester.widget(find.byType(BaselineColumnLayout)),
        isA<BaselineFlexLayout>(),
      );
      expect(tester.getSize(find.byKey(const Key('narrow'))).width, 30);
      expect(tester.getSize(find.byType(BaselineColumnLayout)).width, 30);
    });
  });
}
