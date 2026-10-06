# Changelog

## Unreleased

- Breaking: `StratumNamedCurve.byName` moved to `StratumCurveConvert.byName`, on the Flutter side of the theme models,
  so the curve model compiles in the Dart VM; `stratumCurve.curve` reads as before. No `@Deprecated` step: Dart has no
  static extension members, and no release tag exists yet.
