import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/components/common/web_view/platform/shared/html_bridge_bootstrap.dart';
import 'package:stratum_ui/src/components/common/web_view/platform/shared/message_script.dart';

import '../../fakes/native_bridge_envelope.dart';

final Uri _app = Uri.parse('https://app.example.com');

String _script(String data, {String? token, Set<Uri>? origins}) =>
    buildMessageDispatchScript(
      data,
      token: token,
      allowedOrigins: origins ?? {_app},
    );

const _dataStart = '{data:';
const _dataEnd = '}));return true;})()';

/// Returns the JavaScript string literal embedded in [script].
String _literal(String script) {
  expect(script, contains(_dataStart));
  expect(script, endsWith(_dataEnd));
  return script.substring(
    script.indexOf(_dataStart) + _dataStart.length,
    script.length - _dataEnd.length,
  );
}

void main() {
  test('us03/fr02/e03: a strict-mode IIFE that returns a boolean', () {
    final script = _script('hello', token: 'tok');
    expect(script, startsWith("(function(){'use strict';"));
    expect(script, contains('return false;'));
    expect(script, endsWith(_dataEnd));
    expect(_literal(script), '"hello"');
  });

  test('us03/fr02/e03: checks the token and the allowed origins before '
      'any data appears', () {
    final script = _script('secret-data', token: 'tok');
    final guard = script.indexOf('if(!(');
    expect(guard, greaterThan(-1));
    expect(
      script.substring(guard, script.indexOf('return false;')),
      contains("t==='tok'||o===\"https://app.example.com\""),
    );
    expect(
      script.indexOf('secret-data'),
      greaterThan(script.indexOf('return false;')),
    );
  });

  test('us03/fr04: reads the token from the property the native '
      'bootstrap writes', () {
    expect(
      _script('x', token: 'tok'),
      contains('t=window.$nativeBridgeTokenProperty;'),
    );
  });

  test('us03/fr02/e10: compares each allowed origin as a literal: host '
      'lowercased, default port and path dropped, no page method', () {
    final script = _script(
      'x',
      origins: {
        Uri.parse('https://APP.example.com:443/home'),
        Uri.parse('http://127.0.0.1:8080/bridge'),
      },
    );
    expect(script, contains('o==="https://app.example.com"'));
    expect(script, contains('o==="http://127.0.0.1:8080"'));
    expect(script, contains('o=window.location.origin;'));
    expect(script, isNot(contains('indexOf')));
    expect(script, isNot(contains('includes')));
  });

  test('us03/fr02/e10: without a token only the origin branch runs', () {
    expect(_script('x'), isNot(contains('t===')));
  });

  test('us03/fr05/e08: a reply script admits only the document with the '
      'sending id, by token and id together', () {
    final script = buildMessageDispatchScript(
      'secret-data',
      token: 'tok',
      documentId: documentA,
      allowedOrigins: const <Uri>[],
    );
    final guard = script.indexOf('if(!(');
    final returnFalse = script.indexOf('return false;');
    expect(
      script.substring(guard, returnFalse),
      contains("t==='tok'&&d==='$documentA'"),
    );
    expect(script, contains('d=window.$nativeBridgeDocumentProperty;'));
    expect(script.indexOf('secret-data'), greaterThan(returnFalse));
  });

  test('us03/fr02/e03: a send without a document id reads no document '
      'property', () {
    final script = _script('x', token: 'tok');
    expect(script, isNot(contains('nativeBridgeDocumentProperty')));
    expect(script, isNot(contains(nativeBridgeDocumentProperty)));
    expect(script, startsWith("(function(){'use strict';var t,o;"));
  });

  test('us03/fr02/e03: an entry with no host is left out, and no branch '
      'left means nothing is dispatched', () {
    final script = _script('x', origins: {Uri.parse('about:blank')});
    expect(script, contains('if(!(false))return false;'));
  });

  test('nf01/NFR-Sec05: round-trips data that needs escaping', () {
    const samples = [
      'say "hi"',
      r'back\slash',
      'line\nbreak',
      '</script><script>alert(1)</script>',
      '{"type":"refresh","id":7}',
      'emoji 🎉 and ไทย',
    ];
    for (final sample in samples) {
      final literal = _literal(_script(sample));
      expect(jsonDecode(literal), sample, reason: sample);
    }
  });

  test('nf01/NFR-Sec05: escapes U+2028 and U+2029 for pre-ES2019 '
      'engines', () {
    final literal = _literal(_script('a\u2028b\u2029c'));
    expect(literal, isNot(contains('\u2028')));
    expect(literal, isNot(contains('\u2029')));
    expect(literal, r'"a\u2028b\u2029c"');
    expect(jsonDecode(literal), 'a\u2028b\u2029c');
  });
}
