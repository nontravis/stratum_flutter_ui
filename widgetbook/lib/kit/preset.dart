import 'package:flutter/widgets.dart';
import 'package:widgetbook/widgetbook.dart' hide ThemeMode;

/// A named value a [PresetArg] offers, built from the story's [BuildContext]
/// so it can read theme tokens and the locale.
///
/// A preset may build no value, such as [Preset.none]; a knob for a param that
/// always needs a value takes [RequiredPreset]s instead.
base class Preset<T> {
  const Preset(this.name, this.build);

  /// The preset `None`, which builds no value: the name every optional knob
  /// uses, so a link's `None` reads the same on every page (s03 INV-10).
  const Preset.none() : name = noneName, build = _buildNone;

  /// The name of the preset that builds no value.
  static const noneName = 'None';

  final String name;
  final T? Function(BuildContext context) build;
}

/// The build function of [Preset.none].
T? _buildNone<T>(BuildContext context) => null;

/// A [Preset] that always builds a value, for a knob whose param takes none
/// of `null`. It has no `none` form, so a [RequiredPresetArg] cannot offer a
/// preset that builds nothing, and [valueOf] never throws.
final class RequiredPreset<T extends Object> extends Preset<T> {
  // The value builder narrows to a non-null return, which `super.build`
  // would widen back.
  // ignore: use_super_parameters
  const RequiredPreset(String name, T Function(BuildContext context) value)
    : _value = value,
      super(name, value);

  final T Function(BuildContext context) _value;

  /// The value built for [context].
  T valueOf(BuildContext context) => _value(context);
}

/// A knob that picks one [Preset] from a dropdown; the query value is the
/// preset's name (s03 INV-10).
class PresetArg<T> extends PresetArgBase<Preset<T>> {
  PresetArg(super.value, {super.name, required super.values});
}

/// A knob that picks one [RequiredPreset] from a dropdown, for a param that
/// always needs a value.
class RequiredPresetArg<T extends Object>
    extends PresetArgBase<RequiredPreset<T>> {
  RequiredPresetArg(super.value, {super.name, required super.values});
}

/// The dropdown both preset knobs share; [values] lists the presets it offers.
abstract class PresetArgBase<P extends Preset<Object?>> extends Arg<P>
    with SingleFieldOnly {
  PresetArgBase(super.value, {super.name, required this.values})
    : assert(
        values.map((preset) => preset.name).toSet().length == values.length,
        'Preset names must be unique',
      );

  final List<P> values;

  @override
  Field<P> get field => ObjectDropdownField<P>(
    name: 'value',
    values: values,
    initialValue: value,
    labelBuilder: (preset) => preset.name,
  );
}

/// A knob that picks one of [values], the first by default, named [name].
PresetArg<T> presetKnob<T>(String name, List<Preset<T>> values) =>
    PresetArg(values.first, name: name, values: values);

/// A knob that picks one of [values], the first by default, named [name], for
/// a param that always needs a value.
RequiredPresetArg<T> requiredPresetKnob<T extends Object>(
  String name,
  List<RequiredPreset<T>> values,
) => RequiredPresetArg(values.first, name: name, values: values);
