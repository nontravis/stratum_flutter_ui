@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:stratum_ui/src/themes/value_model.dart';

/// Every value model file on the shared annotation (freezed-models design
/// 5.2, R4 Q1, plan P4). A task that moves a model onto `@valueModel` adds
/// its file here before the switch, so the pins below fail until it lands.
const _valueModelFiles = [
  'lib/src/themes/animation.dart',
  'lib/src/themes/config/animation_config.dart',
  'lib/src/themes/config/format_error.dart',
  'lib/src/themes/config/schema_version.dart',
  'lib/src/themes/config/shadow_layer.dart',
  'lib/src/themes/config/theme_asset.dart',
  'lib/src/themes/config/theme_config.dart',
  'lib/src/themes/config/theme_source.dart',
  'lib/src/themes/remote/remote_theme.dart',
  'lib/src/themes/system/system_bars.dart',
  'lib/src/themes/system/system_style.dart',
  'lib/src/themes/theme_data.dart',
  'lib/src/themes/theme_set.dart',
  'lib/src/themes/typography/dimension.dart',
  'lib/src/themes/typography/typography.dart',
  'lib/src/themes/typography/typography_models.dart',
  // M1-T7: the shipped model of FO-03 (design 5.2).
  'lib/src/application/app_config.dart',
  'lib/src/themes/font_data.dart',
  'lib/src/components/common/style/text_style_builder.dart',
  'lib/src/animations/theme_transitions.dart',
  // M2-T11: the shipped models of FO-05 (design 5.2).
  'lib/src/components/common/model/image_blur_filter.dart',
  'lib/src/components/common/model/widget_style.dart',
  // M3-T12: the shipped model of FO-06 (design 5.2).
  'lib/src/components/common/model/interaction.dart',
  'lib/src/components/common/model/interaction_state.dart',
  'lib/src/components/common/model/scroll.dart',
  'lib/src/components/common/model/focus_group.dart',
  // M3-T16: the shipped models of FO-06 (design 5.2).
  'lib/src/components/common/model/modal_layout/modal_layout_style.dart',
  'lib/src/components/common/model/page_layout/page_areas.dart',
  'lib/src/components/common/model/page_layout/page_layout_style.dart',
  'lib/src/components/common/model/page_layout/page_safe_area.dart',
  'lib/src/components/common/model/page_layout/page_side.dart',
  'lib/src/components/common/model/split_layout/split_divider_state.dart',
  'lib/src/components/common/model/split_layout/split_pane.dart',
  // M4-T17: the shipped models of CO-01-02 (design 5.2).
  'lib/src/components/common/model/web_view/web_view_error.dart',
  'lib/src/components/common/model/web_view/web_view_message.dart',
  'lib/src/components/common/model/web_view/web_view_source.dart',
  // M4-T18: the internal configuration of CO-01-02 (design 5.2, P4).
  'lib/src/components/common/model/web_view/web_view_configuration.dart',
  // M5-T20: the shipped models of CO-05-07 (design 5.2).
  'lib/src/components/common/model/toast/stratum_toast_action.dart',
  'lib/src/components/common/model/toast/stratum_toast_notice.dart',
  'lib/src/components/common/model/toast/stratum_toast_placement.dart',
];

/// The generated file of [source]: `generated/<name>.freezed.dart` beside
/// it, as `build.yaml` writes it.
String _generatedOf(String source) {
  final slash = source.lastIndexOf('/');
  final name = source.substring(slash + 1, source.length - '.dart'.length);
  return '${source.substring(0, slash)}/generated/$name.freezed.dart';
}

final _plainFreezed = RegExp(r'^@freezed\b', multiLine: true);
final _patterns = RegExp(r'^extension \w+Patterns\b', multiLine: true);

void main() {
  test('R4 Q1: valueModel turns map and when off', () {
    expect(valueModel.map, same(FreezedMapOptions.none));
    expect(valueModel.when, same(FreezedWhenOptions.none));
  });

  for (final file in _valueModelFiles) {
    test('R4 Q1: $file takes @valueModel, never a plain @freezed', () {
      final source = File(file).readAsStringSync();

      expect(source, contains('@valueModel'));
      expect(source, isNot(matches(_plainFreezed)));
      expect(source, isNot(contains('@themeModel')));
    });

    test('R4 Q1: the generated file of $file has no map or when', () {
      final generated = File(_generatedOf(file)).readAsStringSync();

      expect(generated, isNot(matches(_patterns)));
    });
  }

  test('R4 Q1, D3: every freezed model file under lib/src is listed above, '
      'and StratumByWindowSize alone keeps its own @Freezed', () {
    final part = RegExp(
      r"^part 'generated/\w+\.freezed\.dart';",
      multiLine: true,
    );
    final withFreezedPart = [
      for (final entity in Directory('lib/src').listSync(recursive: true))
        if (entity is File &&
            entity.path.endsWith('.dart') &&
            !entity.path.contains('/generated/') &&
            part.hasMatch(entity.readAsStringSync()))
          entity.path,
    ];

    expect(withFreezedPart.toSet(), {
      ..._valueModelFiles,
      'lib/src/themes/config/by_window_size.dart',
    });
  });

  test('R4 Q1: no generated file under lib/src holds a map or when '
      'extension', () {
    final generated = [
      for (final entity in Directory('lib/src').listSync(recursive: true))
        if (entity is File && entity.path.endsWith('.freezed.dart')) entity,
    ];

    expect(generated, isNotEmpty);
    for (final file in generated) {
      expect(
        file.readAsStringSync(),
        isNot(matches(_patterns)),
        reason: file.path,
      );
    }
  });
}
