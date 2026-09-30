import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/components/common/layout/container_layout.dart';
import 'package:stratum_ui/src/components/common/layout/wrap_layout.dart';
import 'package:stratum_ui/src/components/common/model/widget_style.dart';

const _style = WidgetStyle(backgroundColor: Color(0xFFFFFFFF));

Widget _host(Widget child) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: Center(child: child),
  );
}

void main() {
  group('WrapLayout', () {
    testWidgets('builds no ContainerLayout without container values',
        (tester) async {
      await tester.pumpWidget(
        _host(const WrapLayout(children: [SizedBox(width: 20, height: 20)])),
      );

      expect(find.byType(ContainerLayout), findsNothing);
    });

    testWidgets('wraps the wrap in ContainerLayout when a style is set',
        (tester) async {
      await tester.pumpWidget(
        _host(
          const WrapLayout(
            style: _style,
            children: [SizedBox(width: 20, height: 20)],
          ),
        ),
      );

      final box = tester.widget<ContainerLayout>(find.byType(ContainerLayout));
      expect(box.style, _style);
    });

    testWidgets('keeps clipBehavior and alignment on the Wrap',
        (tester) async {
      await tester.pumpWidget(
        _host(
          const WrapLayout(
            style: _style,
            clipBehavior: Clip.hardEdge,
            alignment: WrapAlignment.center,
            children: [SizedBox(width: 20, height: 20)],
          ),
        ),
      );

      final wrap = tester.widget<Wrap>(find.byType(Wrap));
      expect(wrap.clipBehavior, Clip.hardEdge);
      expect(wrap.alignment, WrapAlignment.center);
    });
  });
}
