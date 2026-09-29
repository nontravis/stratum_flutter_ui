import 'package:stratum_ui/src/src.dart';

class AppShadow {
  const AppShadow({
    this.baseColor = Colors.black,
  });

  final Color baseColor;

  List<BoxShadow> get xs => [
    BoxShadow(
      offset: Offset.zero,
      blurRadius: 1,
      spreadRadius: 0,
      color: baseColor.withValues(alpha: 0.12),
    ),
    BoxShadow(
      offset: const Offset(0, 1),
      blurRadius: 2,
      spreadRadius: 0,
      color: baseColor.withValues(alpha: 0.12),
    ),
  ];

  List<BoxShadow> get sm => [
    BoxShadow(
      offset: Offset.zero,
      blurRadius: 1,
      spreadRadius: 0,
      color: baseColor.withValues(alpha: 0.12),
    ),

    BoxShadow(
      offset: const Offset(0, 4),
      blurRadius: 8,
      spreadRadius: 0,
      color: baseColor.withValues(alpha: 0.12),
    ),
  ];

  List<BoxShadow> get md => [
    BoxShadow(
      offset: Offset.zero,
      blurRadius: 1,
      spreadRadius: 0,
      color: baseColor.withValues(alpha: 0.12),
    ),

    BoxShadow(
      offset: const Offset(0, 8),
      blurRadius: 16,
      spreadRadius: 0,
      color: baseColor.withValues(alpha: 0.12),
    ),
  ];

  List<BoxShadow> get lg => [
    BoxShadow(
      offset: Offset.zero,
      blurRadius: 1,
      spreadRadius: 0,
      color: baseColor.withValues(alpha: 0.12),
    ),
    BoxShadow(
      offset: const Offset(0, 12),
      blurRadius: 24,
      spreadRadius: 0,
      color: baseColor.withValues(alpha: 0.12),
    ),
  ];

  List<BoxShadow> get xl => [
    BoxShadow(
      offset: Offset.zero,
      blurRadius: 1,
      spreadRadius: 0,
      color: baseColor.withValues(alpha: 0.12),
    ),

    BoxShadow(
      offset: const Offset(0, 24),
      blurRadius: 32,
      spreadRadius: 0,
      color: baseColor.withValues(alpha: 0.12),
    ),
  ];

  List<BoxShadow> get xxl => [
    BoxShadow(
      offset: Offset.zero,
      blurRadius: 1,
      spreadRadius: 0,
      color: baseColor.withValues(alpha: 0.12),
    ),
    BoxShadow(
      offset: const Offset(0, 40),
      blurRadius: 64,
      spreadRadius: 0,
      color: baseColor.withValues(alpha: 0.12),
    ),
  ];
}
