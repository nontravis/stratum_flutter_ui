import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/components/common/l10n/stratum_labels.dart';

/// The folder that holds the ARB files and the Dart generated from them.
const _dir = 'lib/src/components/common/l10n';

/// Each built-in string kind's ARB key and the generated getter that
/// reads it.
final _getters = <String, String Function(StratumLabels)>{
  'closeButtonLabel': (labels) => labels.closeButtonLabel,
  'expanded': (labels) => labels.expanded,
  'collapsed': (labels) => labels.collapsed,
  'removeTagLabel': (labels) => labels.removeTagLabel,
  'loadingLabel': (labels) => labels.loadingLabel,
  'requiredMarker': (labels) => labels.requiredMarker,
  'showMenuLabel': (labels) => labels.showMenuLabel,
  'retryLabel': (labels) => labels.retryLabel,
  'placeholderPageTitle': (labels) => labels.placeholderPageTitle,
};

/// The message entries of the ARB file [name]: every key not starting
/// with `@`.
Map<String, Object?> _messages(String name) {
  final arb = jsonDecode(
    File('$_dir/$name').readAsStringSync(),
  ) as Map<String, Object?>;
  return {
    for (final MapEntry(:key, :value) in arb.entries)
      if (!key.startsWith('@')) key: value,
  };
}

void main() {
  final en = _messages('stratum_labels_en.arb');
  final th = _messages('stratum_labels_th.arb');

  test('us01/fr01: the table holds exactly the 9 built-in string kinds', () {
    expect(en.keys.toSet(), _getters.keys.toSet());
    expect(_getters, hasLength(9));
  });

  test('us01/fr01/e05: the retry label stays in both tables', () {
    expect(en, contains('retryLabel'));
    expect(th, contains('retryLabel'));
  });

  test('us01/fr01/e02: every English entry is non-empty', () {
    for (final MapEntry(:key, :value) in en.entries) {
      expect(value, isA<String>().having((s) => s, key, isNotEmpty));
    }
  });

  test('us01/fr01/e02: every English key has a non-empty Thai entry', () {
    for (final key in en.keys) {
      expect(th[key], isA<String>().having((s) => s, key, isNotEmpty));
    }
  });

  test('us01/fr01/e02: the Thai file holds no key the English file lacks', () {
    expect(th.keys.toSet().difference(en.keys.toSet()), isEmpty);
  });

  test('us01/fr01: the generated table supports exactly en and th', () {
    expect(
      StratumLabels.supportedLocales.map((locale) => locale.languageCode),
      unorderedEquals(['en', 'th']),
    );
  });

  for (final (language, entries) in [('en', en), ('th', th)]) {
    test('us01/fr01: the generated $language table matches its ARB file', () {
      final labels = lookupStratumLabels(Locale(language));
      for (final MapEntry(:key, value: read) in _getters.entries) {
        expect(read(labels), entries[key], reason: key);
      }
    });
  }
}
