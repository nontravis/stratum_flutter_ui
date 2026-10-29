import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/stratum_ui.dart';
import 'package:stratum_ui_widgetbook/components.g.dart';
import 'package:stratum_ui_widgetbook/foundation/widget_style.stories.dart';
import 'package:stratum_ui_widgetbook/foundation/widget_style_knobs.dart';
import 'package:stratum_ui_widgetbook/kit/preset.dart';
import 'package:widgetbook/widgetbook.dart' hide ThemeMode;

import '../support/open_story.dart';

const _sampleKey = widgetStyleSampleKey;
const _playground = 'Foundation/WidgetStyle/Playground';

/// The field names of `WidgetStyle`, in declaration order.
const _fieldNames = [
  'opacity',
  'padding',
  'margin',
  'width',
  'height',
  'minWidth',
  'maxWidth',
  'minHeight',
  'maxHeight',
  'alignment',
  'border',
  'borderRadius',
  'backgroundColor',
  'backgroundGradient',
  'backgroundImage',
  'backgroundBlur',
  'foregroundColor',
  'foregroundGradient',
  'foregroundImage',
  'foregroundBlur',
  'clipBehavior',
  'innerShadow',
  'dropShadow',
  'animationStyle',
];

WidgetStyle? _sampleStyle(WidgetTester tester) =>
    tester.widget<ContainerLayout>(find.byKey(_sampleKey)).style;

StratumTheme _theme(WidgetTester tester) =>
    tester.element(find.byKey(_sampleKey)).theme;

void main() {
  test('fo11/us05/fr02: one knob per WidgetStyle field', () {
    expect([for (final arg in $Playground.args.list) arg?.name], _fieldNames);
  });

  testWidgets('fo11/us05/fr02, fo11/us05/s3: fill, border, radius, and '
      'shadow knobs restyle the sample box', (tester) async {
    await openStory<ContainerLayout>(
      tester,
      _playground,
      knobs: {
        'backgroundColor': 'ff00ff00',
        'border': '4.0',
        'borderRadius': '12.0',
        'padding': '8.0',
        'width': '200.0',
      },
    );
    final style = _sampleStyle(tester)!;
    final theme = _theme(tester);

    expect(style.backgroundColor, const Color(0xff00ff00));
    expect(
      style.border,
      Border.all(width: 4, color: theme.color.border.color.gray),
    );
    expect(style.borderRadius, BorderRadius.circular(12));
    expect(style.padding, const EdgeInsets.all(8));
    expect(style.width, 200);
  });

  testWidgets('fo11/us05/fr02/e01: a shadow knob casts that shadow', (
    tester,
  ) async {
    await openStory<ContainerLayout>(
      tester,
      _playground,
      knobs: {'dropShadow': 'shadow.3', 'innerShadow': 'shadow.1'},
    );
    final style = _sampleStyle(tester)!;
    final theme = _theme(tester);

    expect(style.dropShadow, theme.shadow.level3);
    expect(style.innerShadow, theme.shadow.level1);
  });

  testWidgets('fo11/us05/fr02: a preset knob set to None leaves its field '
      'unset', (tester) async {
    await openStory<ContainerLayout>(tester, _playground);
    final style = _sampleStyle(tester)!;

    expect(style.alignment, isNull);
    expect(style.backgroundGradient, isNull);
    expect(style.foregroundGradient, isNull);
    expect(style.backgroundImage, isNull);
    expect(style.foregroundImage, isNull);
    expect(style.dropShadow, isNull);
    expect(style.innerShadow, isNull);
    expect(style.backgroundBlur, isNull);
    expect(style.border, isNull);
    expect(style.padding, isNull);
  });

  testWidgets('fo11/us05/fr02: the preset knobs build the gradient, image, '
      'and alignment', (tester) async {
    await openStory<ContainerLayout>(
      tester,
      _playground,
      knobs: {
        'alignment': 'bottomRight',
        'backgroundGradient': 'brand.normal to brand.active',
        'foregroundImage': 'sample_image.png',
        'backgroundBlur': '6.0',
      },
    );
    final style = _sampleStyle(tester)!;
    final theme = _theme(tester);

    expect(style.alignment, Alignment.bottomRight);
    expect((style.backgroundGradient! as LinearGradient).colors, [
      theme.color.brand.normal,
      theme.color.brand.active,
    ]);
    expect(
      (style.foregroundImage!.image as AssetImage).assetName,
      'assets/sample_image.png',
    );
    expect(style.backgroundBlur, const ImageBlurFilter(sigmaX: 6, sigmaY: 6));
  });

  testWidgets('fo11/us05/fr02, fo11/us05/s3: every remaining knob lands in '
      'its own field', (tester) async {
    await openStory<ContainerLayout>(
      tester,
      _playground,
      knobs: {
        'opacity': '0.5',
        'margin': '4.0',
        'height': '180.0',
        'minWidth': '150.0',
        'maxWidth': '300.0',
        'minHeight': '120.0',
        'maxHeight': '400.0',
        'foregroundColor': 'ff0000ff',
        'foregroundGradient': 'brand.normal to brand.active',
        'backgroundImage': 'sample_image.png',
        'foregroundBlur': '6.0',
        'clipBehavior': 'hardEdge',
      },
    );
    final style = _sampleStyle(tester)!;
    final theme = _theme(tester);

    expect(style.opacity, 0.5);
    expect(style.margin, const EdgeInsets.all(4));
    expect(style.height, 180);
    expect(style.minWidth, 150);
    expect(style.maxWidth, 300);
    expect(style.minHeight, 120);
    expect(style.maxHeight, 400);
    expect(style.foregroundColor, const Color(0xff0000ff));
    expect((style.foregroundGradient! as LinearGradient).colors, [
      theme.color.brand.normal,
      theme.color.brand.active,
    ]);
    expect(
      (style.backgroundImage!.image as AssetImage).assetName,
      'assets/sample_image.png',
    );
    expect(style.foregroundBlur, const ImageBlurFilter(sigmaX: 6, sigmaY: 6));
    expect(style.clipBehavior, Clip.hardEdge);
  });

  testWidgets('fo11/us05/fr02: the animation knob sets a sine-curve '
      'animation style', (tester) async {
    await openStory<ContainerLayout>(tester, _playground);
    final context = tester.element(find.byKey(_sampleKey));
    final knobs = WidgetStyleKnobs(
      animationStyle: const Duration(milliseconds: 300),
      alignment: _none(),
      backgroundGradient: _none(),
      backgroundImage: _none(),
      foregroundGradient: _none(),
      foregroundImage: _none(),
      innerShadow: _none(),
      dropShadow: _none(),
    );

    expect(
      knobs.toStyle(context).animationStyle,
      AnimationStyle(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOutSine,
      ),
    );

    // The story line `animationStyle: args.animationStyle` must wire the
    // knob through: the sample box carries the story's 200 ms sine default.
    expect(
      _sampleStyle(tester)!.animationStyle,
      AnimationStyle(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOutSine,
      ),
    );
  });

  testWidgets('fo11/us05/fr02: a knob change keeps the sample box, so its '
      'animation style plays the change', (tester) async {
    await openStory<ContainerLayout>(tester, _playground);
    final before = tester.element(find.byKey(_sampleKey));
    expect(_sampleStyle(tester)!.width, isNot(120));

    WidgetbookState.of(before).updateQueryField(
      groupName: 'width',
      fieldName: 'value',
      fieldValue: '120.0',
    );
    await tester.pump();

    expect(_sampleStyle(tester)!.width, 120);
    expect(tester.element(find.byKey(_sampleKey)), same(before));
  });

  test('fo11/us01/fr02: the WidgetStyle page sits under Foundation', () {
    expect(ContainerLayoutComponent.path, 'Foundation');
    expect(ContainerLayoutComponent.name, 'WidgetStyle');
    expect(components, contains(ContainerLayoutComponent));
  });
}

/// A preset that builds nothing, the `None` choice of every preset knob.
Preset<T> _none<T>() => Preset<T>('None', (_) => null);
