import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

/// Whether [node] is a screen-reader stop of its own: a role, a tap, a custom
/// action, or an adjust action.
bool _isActionable(SemanticsNode node) {
  final data = node.getSemanticsData();
  return data.flagsCollection.isButton ||
      data.flagsCollection.isSlider ||
      data.hasAction(SemanticsAction.tap) ||
      data.hasAction(SemanticsAction.increase) ||
      data.hasAction(SemanticsAction.decrease) ||
      (data.customSemanticsActionIds?.isNotEmpty ?? false);
}

/// Every actionable node among [node]'s ancestors and descendants.
List<SemanticsNode> _actionableRelatives(SemanticsNode node) {
  final found = <SemanticsNode>[];
  for (var up = node.parent; up != null; up = up.parent) {
    if (_isActionable(up)) found.add(up);
  }
  void walk(SemanticsNode below) {
    below.visitChildren((child) {
      if (_isActionable(child)) found.add(child);
      walk(child);
      return true;
    });
  }

  walk(node);
  return found;
}

/// Expects the control found by [finder] to be one semantics node that holds
/// its label, its role, its actions, and [customActions] custom actions.
///
/// The role is a button with a tap, or with [slider] a slider with the adjust
/// actions. A semantics identifier makes its node a boundary, which would
/// split these onto two nodes and give a screen reader two stops for one
/// control. Call it under `tester.ensureSemantics()`.
void expectOneActionableNode(
  WidgetTester tester,
  Finder finder, {
  required String label,
  int customActions = 0,
  bool slider = false,
}) {
  final node = tester.getSemantics(finder);
  final data = node.getSemanticsData();

  expect(data.label, contains(label), reason: 'label of $label');
  if (slider) {
    expect(data.flagsCollection.isSlider, isTrue, reason: 'role of $label');
    expect(
      data.hasAction(SemanticsAction.increase) &&
          data.hasAction(SemanticsAction.decrease),
      isTrue,
      reason: 'adjust actions of $label',
    );
  } else {
    expect(data.flagsCollection.isButton, isTrue, reason: 'role of $label');
    expect(
      data.hasAction(SemanticsAction.tap),
      isTrue,
      reason: 'tap of $label',
    );
  }
  expect(
    data.customSemanticsActionIds ?? const <int>[],
    hasLength(customActions),
    reason: 'custom actions of $label',
  );
  expect(
    _actionableRelatives(node),
    isEmpty,
    reason: '$label has a second actionable node',
  );
}
