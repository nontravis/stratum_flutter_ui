@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/stratum_ui.dart';
import 'package:stratum_ui_widgetbook/kit/docs/accessibility_notes_doc_block.dart';
import 'package:stratum_ui_widgetbook/kit/docs/figma_link_doc_block.dart';
import 'package:stratum_ui_widgetbook/kit/docs/usage_doc_block.dart';
import 'package:stratum_ui_widgetbook/kit/preset.dart';
import 'package:stratum_ui_widgetbook/utility/web_view.stories.dart';
import 'package:widgetbook/widgetbook.dart' hide ThemeMode;

void main() {
  test('fo11/us04/fr01: the Web view Playground has one knob per constructor '
      'param', () {
    expect(
      [for (final arg in $Playground.args.list) arg?.name],
      [
        'source',
        'controller',
        'allowedOrigins',
        'javaScriptEnabled',
        'onMessage',
        'onNavigationRequest',
        'onPageStarted',
        'onPageFinished',
        'onError',
      ],
    );
  });

  test('fo11/us04/fr01/e03: slot, callback, and style params take their kit '
      'knobs', () {
    final source = $Playground.args.sourceArg;

    expect($Playground.args.onErrorArg, isA<BoolArg>());
    expect(source, isA<PresetArg<StratumWebViewSource>>());
    expect(
      [
        for (final p in (source as PresetArg<StratumWebViewSource>).values)
          p.name,
      ],
      ['HTML sample', 'flutter.dev'],
    );
  });

  test('fo11/us03/fr01: the Web view docs follow INV-3', () {
    final blocks = StratumWebViewComponent.docsBuilder!([]);

    expect(blocks.map((b) => b.runtimeType), [
      ComponentNameDocBlock,
      FigmaLinkDocBlock,
      DartCommentDocBlock,
      UsageDocBlock,
      AccessibilityNotesDocBlock,
      ArgsDocBlock,
    ]);
  });

  test('fo11/us03/fr01/e03: Web view has no Figma node', () {
    final blocks = StratumWebViewComponent.docsBuilder!([]);

    expect((blocks[1] as FigmaLinkDocBlock).figma, isNull);
  });

  test('fo11/us01/fr02: the Web view page sits under Utility', () {
    expect(StratumWebViewComponent.path, 'Utility');
  });
}
