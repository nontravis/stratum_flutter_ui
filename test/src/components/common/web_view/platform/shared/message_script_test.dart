import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/components/common/web_view/platform/shared/message_script.dart';

const _prefix = 'window.dispatchEvent(new MessageEvent("message", {data: ';
const _suffix = '}));';

/// Returns the JavaScript string literal embedded in [script].
String _literal(String script) {
  expect(script, startsWith(_prefix));
  expect(script, endsWith(_suffix));
  return script.substring(_prefix.length, script.length - _suffix.length);
}

void main() {
  test('wraps the data in a message event', () {
    expect(buildMessageDispatchScript('hello'), '$_prefix"hello"$_suffix');
  });

  test('round-trips data that needs escaping', () {
    const samples = [
      'say "hi"',
      r'back\slash',
      'line\nbreak',
      '</script><script>alert(1)</script>',
      '{"type":"refresh","id":7}',
      'emoji 🎉 and ไทย',
    ];
    for (final sample in samples) {
      final literal = _literal(buildMessageDispatchScript(sample));
      expect(jsonDecode(literal), sample, reason: sample);
    }
  });

  test('escapes U+2028 and U+2029 for pre-ES2019 engines', () {
    final literal = _literal(buildMessageDispatchScript('a\u2028b\u2029c'));
    expect(literal, isNot(contains('\u2028')));
    expect(literal, isNot(contains('\u2029')));
    expect(literal, r'"a\u2028b\u2029c"');
    expect(jsonDecode(literal), 'a\u2028b\u2029c');
  });
}
