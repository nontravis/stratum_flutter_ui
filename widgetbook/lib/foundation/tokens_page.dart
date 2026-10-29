import 'package:stratum_ui/stratum_ui.dart';

/// Lists every token group of the active theme: color, space, radius,
/// typography, and shadow, each row with its name and a sample drawn with its
/// value.
///
/// Reads the theme data and mode that the catalog toolbar sets, in `build`,
/// and holds no token value of its own, so a toolbar change redraws every row
/// (fo11/us05/fr01; s03 INV-12). The color group lists the names of the
/// generated color listing `StratumColorTokens.byName`.
class TokensPage extends StatelessWidget {
  const TokensPage({super.key});

  @override
  Widget build(BuildContext context) {
    final data = StratumThemeApplication.of(context);
    final theme = context.theme;
    final windowSize = WindowSizeScope.of(context);
    final windowWidth = MediaQuery.sizeOf(context).width;

    final bar = theme.color.background.color.brand;
    final outline = theme.color.border.color.gray;
    final surface = theme.color.background.defaults.surface;
    final gap = theme.space.lg;

    double pixels(StratumByWindowSize<StratumDimension> token) =>
        token.valueFor(windowSize).resolve(of: windowWidth);

    String written(StratumByWindowSize<StratumDimension> token) =>
        _describe(token.valueFor(windowSize));

    final shadows = [
      data.shadow.level1,
      data.shadow.level2,
      data.shadow.level3,
      data.shadow.level4,
      data.shadow.level5,
      data.shadow.level6,
    ];

    return RowLayout(
      scroll: const Scroll(),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ColumnLayout(
          scroll: const Scroll(),
          crossAxisAlignment: CrossAxisAlignment.start,
          gap: gap * 2,
          children: [
            _Group(
              title: 'Color',
              rows: [
                for (final MapEntry(:key, :value) in data.color.byName.entries)
                  _TokenRow(
                    group: 'color',
                    name: key,
                    sample: ContainerLayout(
                      key: ValueKey('tokens.color.$key'),
                      style: WidgetStyle(
                        width: _swatchWidth,
                        height: _sampleHeight,
                        backgroundColor: value,
                        border: Border.all(color: outline),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
              ],
            ),
            _Group(
              title: 'Space',
              rows: [
                for (final MapEntry(:key, :value) in data.space.entries)
                  _TokenRow(
                    group: 'space',
                    name: key,
                    value: written(value),
                    sample: _bar(
                      key: ValueKey('tokens.space.$key'),
                      width: pixels(value),
                      color: bar,
                    ),
                  ),
              ],
            ),
            _Group(
              title: 'Radius',
              rows: [
                for (final MapEntry(:key, :value) in data.radius.entries)
                  _TokenRow(
                    group: 'radius',
                    name: key,
                    value: written(value),
                    sample: _bar(
                      key: ValueKey('tokens.radius.$key'),
                      width: pixels(value),
                      color: bar,
                    ),
                  ),
              ],
            ),
            _Group(
              title: 'Typography',
              rows: [
                for (final MapEntry(:key, :value)
                    in data.typography.types.entries)
                  _TokenRow(
                    group: 'typography',
                    name: key.name,
                    nameStyle: StratumTextStyle.type(key)
                        .size(_sampleSize(value))
                        .build(context),
                  ),
              ],
            ),
            _Group(
              title: 'Shadow',
              rows: [
                for (final (index, boxShadows) in shadows.indexed)
                  _TokenRow(
                    group: 'shadow',
                    name: 'shadow.${index + 1}',
                    sample: ContainerLayout(
                      key: ValueKey('tokens.shadow.${index + 1}'),
                      style: WidgetStyle(
                        width: _shadowBoxWidth,
                        height: _shadowBoxHeight,
                        margin: EdgeInsets.all(gap),
                        backgroundColor: surface,
                        borderRadius: BorderRadius.circular(8),
                        dropShadow: boxShadows,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  static const double _swatchWidth = 48;
  static const double _sampleHeight = 24;
  static const double _barHeight = 8;
  static const double _shadowBoxWidth = 96;
  static const double _shadowBoxHeight = 48;

  static Widget _bar({
    required Key key,
    required double width,
    required Color color,
  }) => ContainerLayout(
    key: key,
    style: WidgetStyle(
      width: width,
      height: _barHeight,
      backgroundColor: color,
    ),
  );

  /// The length as the theme file writes it: `8 px`, or `50%` for a percent.
  static String _describe(StratumDimension dimension) => switch (dimension) {
    FixedDimension(:final px) => '${_trim(px)} px',
    PercentDimension(:final ratio) => '${_trim(ratio * 100)}%',
  };

  /// The size of [style] nearest 16 px, so a type that defines no `s16` draws
  /// its name at a size it has.
  static double _sampleSize(StratumTypeStyle style) => style.sizes.keys
      .map((size) => size.value)
      .reduce((a, b) => (a - 16).abs() <= (b - 16).abs() ? a : b);

  /// [value] with at most two decimals and no trailing zero.
  static String _trim(double value) =>
      value.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');
}

/// A heading above the rows of one token group.
class _Group extends StatelessWidget {
  const _Group({required this.title, required this.rows});

  final String title;
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) => ColumnLayout(
    crossAxisAlignment: CrossAxisAlignment.start,
    gap: context.theme.space.sm,
    children: [
      Semantics(
        header: true,
        child: Text(title, style: StratumTextStyle.header.s20.build(context)),
      ),
      ...rows,
    ],
  );
}

/// One token: its name, an optional written value, and an optional sample.
class _TokenRow extends StatelessWidget {
  const _TokenRow({
    required this.group,
    required this.name,
    this.value,
    this.nameStyle,
    this.sample,
  });

  /// The group key that keeps the row key apart from the same name in
  /// another group (`space.lg` and `radius.lg`).
  final String group;
  final String name;
  final String? value;
  final TextStyle? nameStyle;
  final Widget? sample;

  static const double _nameWidth = 320;
  static const double _valueWidth = 72;

  @override
  Widget build(BuildContext context) => RowLayout(
    key: ValueKey('tokens.row.$group.$name'),
    gap: context.theme.space.md,
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      ContainerLayout(
        style: const WidgetStyle(width: _nameWidth),
        child: Text(name, style: nameStyle),
      ),
      if (value case final value?)
        ContainerLayout(
          style: const WidgetStyle(width: _valueWidth),
          child: Text(value),
        ),
      ?sample,
    ],
  );
}
