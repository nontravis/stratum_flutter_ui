import 'package:freezed_annotation/freezed_annotation.dart';

/// The freezed options of every Stratum value model (freezed-models design
/// 5.2, R4 Q1): `==`, `hashCode`, `toString`, and `copyWith`, and no `map`
/// or `when` pattern extension, so a sealed value is read with a Dart
/// `switch`. It sits in the themes layer, the lowest one, and imports no
/// Flutter, so every layer and every Flutter-free theme file may use it.
/// Internal: not exported.
const valueModel = Freezed(
  map: FreezedMapOptions.none,
  when: FreezedWhenOptions.none,
);
