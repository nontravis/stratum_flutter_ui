import 'package:stratum_ui/src/src.dart';

class Slot extends StatelessWidget {
  const new({
    super.key,
    this.height,
    this.width,
    this.padding,
    this.name = 'Slot',
  });

  final double? height;
  final double? width;
  final EdgeInsets? padding;
  final String name;

  @override
  Widget build(BuildContext context) => DottedBorder(
    options: RoundedRectDottedBorderOptions(
      dashPattern: [4, 4],
      strokeWidth: 1,
      radius: const Radius.circular(6),
      padding: padding ?? const EdgeInsets.all(12),
      color: const Color(0xFF9747FF),
    ),
    child: ContainerLayout(
      style: WidgetStyle(
        width: width,
        height: height,
        alignment: Alignment.center,
      ),
      child: Text(
        '❖ $name',
        style: const TextStyle(
          color: Color(0xFF9747FF),
          fontSize: 16,
          fontWeight: FontWeight.w400,
        ),
      ),
    ),
  );
}
