import 'package:freezed_annotation/freezed_annotation.dart';

/// The freezed options of every theme value model (design N1, Q8): `==`,
/// `hashCode`, `toString`, and `copyWith`, and no `map` or `when` pattern
/// extension, so the public API gains only `copyWith` (design section 2).
/// Internal: not exported.
const themeModel = Freezed(
  map: FreezedMapOptions.none,
  when: FreezedWhenOptions.none,
);
