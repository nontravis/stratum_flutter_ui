import 'package:stratum_ui/src/src.dart';

/// Whether primary focus is inside an [EditableText].
///
/// Text-editing shortcuts sit at the app root, so a key binding between a
/// text field and the root would take Home, End, arrows, and letters from
/// it. A key handler returns early while this holds, so the key reaches the
/// text field. `StratumInkWell` does so for `shortcuts` bindings without a
/// control, meta, or alt modifier, and the layouts' focus groups and
/// keyboard scrolling do so for their keys.
bool primaryFocusInEditableText() {
  final context = FocusManager.instance.primaryFocus?.context;
  if (context == null) return false;
  return context.widget is EditableText ||
      context.findAncestorWidgetOfExactType<EditableText>() != null;
}
