import 'package:flutter/widgets.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:stratum_ui/src/themes/value_model.dart';

part 'generated/stratum_toast_action.freezed.dart';

/// One button on a notice: a tap runs [onPressed] and closes the notice
/// (US-01 FR-01, FR-04).
@valueModel
class StratumToastAction with _$StratumToastAction {
  const new({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;
}
