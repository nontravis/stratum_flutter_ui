import 'package:flutter/widgets.dart';
import 'package:widgetbook/widgetbook.dart' hide ThemeMode;

/// A named value a [PresetArg] offers, built from the story's [BuildContext]
/// so it can read theme tokens and the locale.
final class Preset<T> {
  const Preset(this.name, this.build);

  final String name;
  final T? Function(BuildContext context) build;
}

/// A knob that picks one [Preset] from a dropdown; the query value is the
/// preset's name (s03 INV-10).
class PresetArg<T> extends Arg<Preset<T>> with SingleFieldOnly {
  PresetArg(super.value, {super.name, required this.values})
    : assert(
        values.map((preset) => preset.name).toSet().length == values.length,
        'Preset names must be unique',
      );

  final List<Preset<T>> values;

  @override
  Field<Preset<T>> get field => ObjectDropdownField<Preset<T>>(
    name: 'value',
    values: values,
    initialValue: value,
    labelBuilder: (preset) => preset.name,
  );
}
