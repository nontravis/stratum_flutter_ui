import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'generated/app_config.freezed.dart';

/// Builds the app from `StratumApplication`'s current [StratumAppConfig].
typedef StratumAppBuilder = Widget Function(
  BuildContext context,
  StratumAppConfig stratum,
);

/// The values `StratumApplication` hands its [StratumAppBuilder] (FO-03
/// US-13 FR-02), built again each time the active theme or mode changes
/// (themes s03 invariant 35).
@freezed
class StratumAppConfig with _$StratumAppConfig {
  const new({
    required this.theme,
    required this.darkTheme,
    required this.themeMode,
    required this.builder,
  });

  /// The Material theme of the active data's light set (US-08 FR-01).
  final ThemeData theme;

  /// The Material theme of the active data's dark set, null with none.
  final ThemeData? darkTheme;

  /// The theme mode `StratumApplication.themeMode` passed.
  final ThemeMode themeMode;

  /// Inserts the theme application and the other inner layers of FR-01,
  /// outer to inner, around its child; an app with a builder of its own
  /// chains it as `stratum.builder(context, MyWrapper(child: child!))`
  /// (FR-03).
  final TransitionBuilder builder;
}
