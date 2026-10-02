import 'package:flutter/foundation.dart';

/// One `theme.yaml` file that `StratumThemeConfig.parse` reads.
@immutable
class StratumThemeSource {
  const new({required this.id, required this.folder, required this.yaml});

  /// The theme id that every error from this file carries as `source`.
  /// The caller keeps ids distinct; the package default and an app's own
  /// `default` need different ids (sub-project 4 picks them).
  final String id;

  /// The folder that holds the file, for example
  /// `packages/stratum_ui/assets/themes/default`. Asset slot paths the file
  /// sets resolve against it.
  final String folder;

  /// The text of the file.
  final String yaml;

  @override
  bool operator ==(Object other) =>
      other is StratumThemeSource &&
      other.id == id &&
      other.folder == folder &&
      other.yaml == yaml;

  @override
  int get hashCode => Object.hash(id, folder, yaml);

  @override
  String toString() => 'StratumThemeSource(id: $id, folder: $folder)';
}
