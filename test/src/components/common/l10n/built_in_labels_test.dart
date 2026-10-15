import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/components/common/l10n/built_in_labels.dart';

/// [child] under a bare [Localizations] for [locale] that holds widgets
/// localizations only.
Widget _localeHost(Locale locale, Widget child) {
  return Localizations(
    locale: locale,
    delegates: const [DefaultWidgetsLocalizations.delegate],
    child: child,
  );
}

/// A widget that records the show menu label [builtInLabelsOf] reads on
/// every build into [labels].
Widget _probe(List<String> labels) {
  return Builder(
    builder: (context) {
      labels.add(builtInLabelsOf(context).showMenuLabel);
      return const SizedBox();
    },
  );
}

void main() {
  group('builtInLabelsFor', () {
    test('fo09/us01/fr01: th reads the Thai entry', () {
      expect(builtInLabelsFor(const Locale('th')).showMenuLabel, 'แสดงเมนู');
    });

    test(
      'fo09/us01/fr01: th_TH matches by language and reads the Thai entry',
      () {
        expect(
          builtInLabelsFor(const Locale('th', 'TH')).showMenuLabel,
          'แสดงเมนู',
        );
      },
    );

    test('fo09/us01/fr01: en reads the English entry', () {
      expect(builtInLabelsFor(const Locale('en')).showMenuLabel, 'Show menu');
    });

    test(
      'fo09/us01/fr01/e03: ja, a language the table lacks, reads English',
      () {
        expect(builtInLabelsFor(const Locale('ja')).showMenuLabel, 'Show menu');
      },
    );

    test('fo09/us01/fr01/e03: zh_Hant_TW reads English and never throws', () {
      expect(
        builtInLabelsFor(
          const Locale.fromSubtags(
            languageCode: 'zh',
            scriptCode: 'Hant',
            countryCode: 'TW',
          ),
        ).showMenuLabel,
        'Show menu',
      );
    });

    test(
      'fo09/us01/fr01/e03: an uppercase language code reads the same table',
      () {
        expect(builtInLabelsFor(const Locale('TH')).showMenuLabel, 'แสดงเมนู');
        expect(
          builtInLabelsFor(const Locale('EN', 'US')).showMenuLabel,
          'Show menu',
        );
      },
    );

    test('fo09/us01/fr01/e03: an undetermined language reads English', () {
      expect(
        builtInLabelsFor(const Locale.fromSubtags()).showMenuLabel,
        'Show menu',
      );
    });
  });

  group('builtInLabelsOf', () {
    testWidgets('fo09/us01/fr01: reads the nearest Localizations locale', (
      tester,
    ) async {
      final labels = <String>[];
      await tester.pumpWidget(_localeHost(const Locale('th'), _probe(labels)));

      expect(labels.last, 'แสดงเมนู');
    });

    testWidgets(
      'fo09/us01/fr01: with no Localizations reads the platform locale',
      (tester) async {
        tester.platformDispatcher.localeTestValue = const Locale('th', 'TH');
        addTearDown(tester.platformDispatcher.clearLocaleTestValue);
        final labels = <String>[];
        await tester.pumpWidget(_probe(labels));

        expect(labels.last, 'แสดงเมนู');
      },
    );

    testWidgets(
      'fo09/us01/fr01: a locale change rebuilds in the new language',
      (tester) async {
        final labels = <String>[];
        final probe = _probe(labels);
        await tester.pumpWidget(_localeHost(const Locale('en'), probe));
        await tester.pumpWidget(_localeHost(const Locale('th'), probe));

        expect(labels.first, 'Show menu');
        expect(labels.last, 'แสดงเมนู');
      },
    );

    testWidgets(
      'fo09/us01/fr01/e03: a locale change to an unsupported language '
      'rebuilds in English',
      (tester) async {
        final labels = <String>[];
        final probe = _probe(labels);
        await tester.pumpWidget(_localeHost(const Locale('th'), probe));
        await tester.pumpWidget(_localeHost(const Locale('ja'), probe));

        expect(labels.first, 'แสดงเมนู');
        expect(labels.last, 'Show menu');
      },
    );
  });
}
