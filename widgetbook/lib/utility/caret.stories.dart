import 'package:stratum_ui/stratum_ui.dart';
import 'package:widgetbook/widgetbook.dart' hide ThemeMode;

import '../kit/docs/catalog_docs.dart';
import '../kit/docs/stratum_docs.dart';
import '../kit/preset.dart';
import '../kit/sample_text.dart';
import '../kit/story_set.dart';
import '../shell/catalog_section.dart';
import 'caret_knobs.dart';

part 'caret.stories.g.dart';

final _docs = CatalogDocs(
  figma: Uri.parse(
    'https://www.figma.com/design/wjRe9eL7863nMRfFats8jZ/'
    'Design-System-4-by-Nonthawit?node-id=56236-100390',
  ),
  usage: '''
StratumCaret(
  direction: isOpen
      ? StratumCaretDirection.up
      : StratumCaretDirection.down,
  size: WidgetSize.small,
)''',
  dos: [
    'Put it on a control that opens a dropdown, select menu, or disclosure.',
    'Turn it with direction when the control opens or closes.',
  ],
  donts: [
    'Use it to move between pages or steps; use an arrow or chevron icon.',
    'Use it as decoration on an element that does not expand.',
  ],
  accessibility: [
    'The caret stays out of the semantics tree; the owning control '
        'announces expanded or collapsed.',
    'Start and end point by the reading direction, so the caret mirrors '
        'under right to left.',
  ],
);

const meta = Meta(StratumCaret.new, argsType: CaretKnobs.new);

final componentMeta = ComponentMeta(
  name: 'Caret',
  path: CatalogSection.utility.label,
  docsBuilder: stratumDocs(
    _docs,
    args: [for (final arg in $Playground.args.list) ?arg],
  ),
);

/// A fresh set of knobs: one per constructor param, in constructor order.
CaretKnobsArgs _knobs() => CaretKnobsArgs(
  customStyle: PresetArg(
    _customStyles.first,
    name: 'customStyle',
    values: _customStyles,
  ),
);

final _customStyles = <Preset<StratumCaretStyle>>[
  const Preset('None', _noStyle),
  Preset(
    'Filled box',
    (context) => StratumCaretStyle(
      backgroundColor: context.theme.color.background.color.gray,
      borderRadius: BorderRadius.circular(context.theme.radius.lg),
      margin: EdgeInsets.all(context.theme.space.sm),
    ),
  ),
  Preset(
    'Outlined box',
    (context) => StratumCaretStyle(
      border: Border.all(color: context.theme.color.border.color.gray),
      borderRadius: BorderRadius.circular(context.theme.radius.lg),
      margin: EdgeInsets.all(context.theme.space.sm),
    ),
  ),
];

StratumCaretStyle? _noStyle(BuildContext context) => null;

/// The page widget Widgetbook's builder must return; the frame stories show
/// their own layout through `setup`, which drops this child.
StratumCaret _frameChild(BuildContext context, CaretKnobsArgs args) =>
    const StratumCaret();

/// The Variants grid in the order of the Figma page: glyph rows Regular,
/// Light, Fill; direction rows Down, Up, Right, Left.
const _glyphOrder = [
  StratumCaretGlyph.regular,
  StratumCaretGlyph.light,
  StratumCaretGlyph.fill,
];
const _directionOrder = [
  StratumCaretDirection.down,
  StratumCaretDirection.up,
  StratumCaretDirection.end,
  StratumCaretDirection.start,
];

/// Every glyph x direction x size, each enabled then disabled; a row is wider
/// than a narrow preview, so the grid scrolls both ways.
Widget _variantsGrid() => RowLayout(
  scroll: const Scroll(),
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [_variantsColumn()],
);

Widget _variantsColumn() => ColumnLayout(
  scroll: const Scroll(),
  crossAxisAlignment: CrossAxisAlignment.start,
  gap: 16,
  children: [
    for (final glyph in _glyphOrder)
      ColumnLayout(
        crossAxisAlignment: CrossAxisAlignment.start,
        gap: 8,
        children: [
          Text(glyph.name),
          for (final direction in _directionOrder)
            RowLayout(
              gap: 12,
              children: [
                ContainerLayout(
                  style: const WidgetStyle(width: 56),
                  child: Text(direction.name),
                ),
                for (final size in WidgetSize.values)
                  RowLayout(
                    gap: 4,
                    children: [
                      StratumCaret(
                        style: glyph,
                        direction: direction,
                        size: size,
                      ),
                      StratumCaret(
                        style: glyph,
                        direction: direction,
                        size: size,
                        disabled: true,
                      ),
                    ],
                  ),
              ],
            ),
        ],
      ),
  ],
);

final $Playground = _Story(
  args: _knobs(),
  builder: (context, args) => StratumCaret(
    style: args.style,
    direction: args.direction,
    size: args.size,
    customSize: args.customSize,
    color: args.color,
    customColor: args.customColor,
    themeMode: args.themeMode,
    disabled: args.disabled,
    customStyle: args.customStyle.build(context),
  ),
);

final $Variants = _Story(
  args: _knobs(),
  builder: _frameChild,
  setup: (_, _, _) => _variantsGrid(),
);

final $Responsive = _Story(
  args: _knobs(),
  builder: _frameChild,
  setup: (_, _, _) => responsiveFrames((context) => const StratumCaret()),
);

final $Accessibility = _Story(
  args: _knobs(),
  builder: _frameChild,
  setup: (_, _, _) => accessibilityFrames(
    build: (context) => const StratumCaret(),
    disabled: (context) => const StratumCaret(disabled: true),
  ),
);

final $ExampleDropdownTrigger = _Story(
  name: StoryNames.example('dropdown trigger'),
  args: _knobs(),
  builder: _frameChild,
  setup: (_, _, _) => const _DropdownTriggers(),
);

/// A closed and an open dropdown trigger, each a label with a caret.
class _DropdownTriggers extends StatelessWidget {
  const _DropdownTriggers();

  @override
  Widget build(BuildContext context) {
    final label = SampleTexts.label.resolve(Localizations.localeOf(context));
    return ColumnLayout(
      crossAxisAlignment: CrossAxisAlignment.start,
      gap: 12,
      children: [
        RowLayout(
          gap: 8,
          children: [
            Text(label),
            const StratumCaret(size: WidgetSize.small),
          ],
        ),
        RowLayout(
          gap: 8,
          children: [
            Text(label),
            const StratumCaret(
              size: WidgetSize.small,
              direction: StratumCaretDirection.up,
            ),
          ],
        ),
      ],
    );
  }
}
