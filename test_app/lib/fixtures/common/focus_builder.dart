import 'package:stratum_ui/stratum_ui.dart';

/// Group-label fixture for the `semantics` of a `FocusBuilder` (FO-06 US-16
/// FR-04 E01).
///
/// Text `Delivery form` (id `focus_builder.heading`), then the address group
/// labeled `ที่อยู่จัดส่ง` around one plain text field labeled `ถนน`, as a
/// Developer writes it. The group and its field read at one stop, the group
/// label first, then the field. The group and the field carry no id: an id
/// would split the label onto a node of its own, so a test finds the stop by
/// its label.
class FocusBuilderFixture extends StatelessWidget {
  const FocusBuilderFixture({super.key});

  @override
  Widget build(BuildContext context) {
    return ColumnLayout(
      mainAxisAlignment: MainAxisAlignment.center,
      gap: 8,
      children: [
        Semantics(
          identifier: 'focus_builder.heading',
          child: const Text('Delivery form'),
        ),
        FocusBuilder(
          semantics: const SemanticsProperties(label: 'ที่อยู่จัดส่ง'),
          builder: (context, focused, child) => child!,
          child: const ContainerLayout(
            style: WidgetStyle(width: 280),
            child: TextField(decoration: InputDecoration(labelText: 'ถนน')),
          ),
        ),
      ],
    );
  }
}
