import 'package:flutter/foundation.dart';

/// How the file of an asset slot renders, read from its extension.
enum StratumAssetKind {
  /// `png`, `jpg`, `jpeg`, `webp`, or `gif`.
  image,

  /// `svg`.
  svg,

  /// `json` or `lottie`: a Lottie animation.
  lottie;

  /// The kind for a file [extension] in any case; null for any other
  /// extension.
  static StratumAssetKind? fromExtension(String extension) =>
      switch (extension.toLowerCase()) {
        'png' || 'jpg' || 'jpeg' || 'webp' || 'gif' => image,
        'svg' => svg,
        'json' || 'lottie' => lottie,
        _ => null,
      };
}

/// One asset slot of a theme (`splash-screen`, `loading`).
@immutable
class StratumThemeAsset {
  const new({required this.kind, required this.path});

  /// How the file renders.
  final StratumAssetKind kind;

  /// The folder of the file that set the slot, a single `/`, then the
  /// slot's relative path.
  final String path;

  @override
  bool operator ==(Object other) =>
      other is StratumThemeAsset && other.kind == kind && other.path == path;

  @override
  int get hashCode => Object.hash(kind, path);

  @override
  String toString() => 'StratumThemeAsset(kind: ${kind.name}, path: $path)';
}
