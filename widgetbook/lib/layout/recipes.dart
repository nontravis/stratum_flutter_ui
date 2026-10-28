import 'package:stratum_ui/stratum_ui.dart';

import 'layout_slots.dart';

/// A label beside its field, in a row of two slot placeholders (fo11/us06/fr02).
class FormRowRecipe extends StatelessWidget {
  const FormRowRecipe({super.key});

  @override
  Widget build(BuildContext context) => RowLayout(
    gap: context.theme.space.md,
    children: const [
      StratumSlot(name: 'label'),
      StratumSlot(name: 'field'),
    ],
  );
}

/// A media, title, and body above a row of actions, in a Card styled box
/// (fo11/us06/fr02).
class CardRecipe extends StatelessWidget {
  const CardRecipe({super.key});

  @override
  Widget build(BuildContext context) => ContainerLayout(
    style: _card.build(context),
    child: ColumnLayout(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      gap: context.theme.space.sm,
      children: [
        const StratumSlot(name: 'media'),
        const StratumSlot(name: 'title'),
        const StratumSlot(name: 'body'),
        RowLayout(
          gap: context.theme.space.sm,
          children: const [StratumSlot(name: 'action')],
        ),
      ],
    ),
  );

  static final _card = widgetStylePresets.firstWhere(
    (preset) => preset.name == 'Card',
  );
}

/// A leading slot, a title over a subtitle, and a trailing slot in one row
/// (fo11/us06/fr02).
class ListItemRecipe extends StatelessWidget {
  const ListItemRecipe({super.key});

  @override
  Widget build(BuildContext context) => RowLayout(
    crossAxisAlignment: CrossAxisAlignment.center,
    gap: context.theme.space.md,
    children: [
      const StratumSlot(name: 'leading'),
      ColumnLayout(
        gap: context.theme.space.xs,
        children: const [
          StratumSlot(name: 'title'),
          StratumSlot(name: 'subtitle'),
        ],
      ),
      const StratumSlot(name: 'trailing'),
    ],
  );
}

/// A leading slot, a title, and an actions slot in one row (fo11/us06/fr02).
class ToolbarRecipe extends StatelessWidget {
  const ToolbarRecipe({super.key});

  @override
  Widget build(BuildContext context) => RowLayout(
    crossAxisAlignment: CrossAxisAlignment.center,
    gap: context.theme.space.md,
    children: const [
      StratumSlot(name: 'leading'),
      StratumSlot(name: 'title'),
      StratumSlot(name: 'actions'),
    ],
  );
}

/// A page with a header, a drawer on its start side, and a body
/// (fo11/us06/fr02).
///
/// Needs bounded constraints, as every [PageLayout] does.
class PageWithDrawerRecipe extends StatelessWidget {
  const PageWithDrawerRecipe({super.key});

  @override
  Widget build(BuildContext context) => const PageLayout(
    header: StratumSlot(name: 'header'),
    left: StratumSlot(name: 'drawer'),
    body: StratumSlot(name: 'body'),
  );
}
