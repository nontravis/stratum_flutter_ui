import 'package:stratum_ui/src/src.dart';

/// A theme length: a fixed number of logical pixels, or a percent of a base
/// length that the caller supplies when it resolves the value.
///
/// In `theme.yaml` a bare number is fixed (`8`) and a string `"N%"` is a
/// percent (`"50%"`, `"-1.2%"`).
@immutable
sealed class StratumDimension {
  const new();

  /// A length of [px] logical pixels.
  const factory fixed(double px) = FixedDimension;

  /// A length of [ratio] times the base it resolves against; `0.5` is 50%.
  const factory percent(double ratio) = PercentDimension;

  /// Reads a `theme.yaml` value: a number gives [StratumDimension.fixed]; a
  /// string `"N%"` gives [StratumDimension.percent] of `N / 100`.
  ///
  /// Throws a [FormatException] for anything else.
  factory parse(Object? value) {
    if (value is num) return StratumDimension.fixed(value.toDouble());
    if (value is String && _percentPattern.hasMatch(value)) {
      final number = double.parse(value.substring(0, value.length - 1));
      return StratumDimension.percent(number / 100);
    }
    final shown = value is String ? '"$value"' : '$value';
    throw FormatException('expected a number or "N%", got $shown');
  }

  static final _percentPattern = RegExp(r'^-?\d+(\.\d+)?%$');

  /// The length in logical pixels; [of] is the base a percent value
  /// resolves against.
  double resolve({required double of});
}

/// A [StratumDimension] of [px] logical pixels.
final class FixedDimension extends StratumDimension {
  const new(this.px);

  /// The length in logical pixels.
  final double px;

  @override
  double resolve({required double of}) => px;

  @override
  bool operator ==(Object other) => other is FixedDimension && other.px == px;

  @override
  int get hashCode => Object.hash(FixedDimension, px);

  @override
  String toString() => 'StratumDimension.fixed($px)';
}

/// A [StratumDimension] of [ratio] times the base it resolves against.
final class PercentDimension extends StratumDimension {
  const new(this.ratio);

  /// The share of the base; `0.5` is 50%.
  final double ratio;

  @override
  double resolve({required double of}) => ratio * of;

  @override
  bool operator ==(Object other) =>
      other is PercentDimension && other.ratio == ratio;

  @override
  int get hashCode => Object.hash(PercentDimension, ratio);

  @override
  String toString() => 'StratumDimension.percent($ratio)';
}
