import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:stratum_ui/src/themes/config/theme_model.dart';

part 'generated/schema_version.freezed.dart';

/// The `$schema` version of a `theme.yaml` file:
/// `stratum-theme/v<major>.<minor>.<patch>`.
@immutable
@themeModel
class StratumSchemaVersion with _$StratumSchemaVersion {
  const new(this.major, this.minor, this.patch);

  /// The newest version this package reads: `stratum-theme/v1.4.0`, the
  /// version that adds the `system` group (config s03 invariant 16), after
  /// `v1.1.0` added `opacity` with `disabled`, `v1.2.0` added the
  /// `border`, `shadow`, and `blur` groups (invariants 12 to 14), and
  /// `v1.3.0` added `opacity.scrim` (invariant 11).
  static const current = StratumSchemaVersion(1, 4, 0);

  static final _pattern = RegExp(r'^stratum-theme/v(\d+)\.(\d+)\.(\d+)$');

  /// Reads `stratum-theme/v<major>.<minor>.<patch>`; null when [value] does
  /// not match.
  static StratumSchemaVersion? tryParse(String value) {
    final match = _pattern.firstMatch(value);
    if (match == null) return null;
    final major = int.tryParse(match[1]!);
    final minor = int.tryParse(match[2]!);
    final patch = int.tryParse(match[3]!);
    if (major == null || minor == null || patch == null) return null;
    return StratumSchemaVersion(major, minor, patch);
  }

  final int major;
  final int minor;
  final int patch;

  /// The same major as [current] and a minor no newer than its; any patch.
  bool get isSupported => major == current.major && minor <= current.minor;

  @override
  String toString() => 'stratum-theme/v$major.$minor.$patch';
}
