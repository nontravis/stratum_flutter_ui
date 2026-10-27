/// The keys of one `theme.yaml` `focus` set, flattened with dots, in the
/// order stage 5 reads them (config s03 INV-19): the outside ring's
/// color, width, and gap, and the inside ring's color and its hovered and
/// focused widths. The inside ring has no gap, since the gap never applies
/// inward.
const focusKeys = <String>[
  'outside.color',
  'outside.width',
  'outside.gap',
  'inside.color',
  'inside.width.hovered',
  'inside.width.focused',
];
