import 'dart:convert';

/// Builds a script that delivers [data] to the page as a `message` event.
///
/// [jsonEncode] turns [data] into a valid JavaScript string literal: quotes,
/// backslashes, and control characters are escaped. U+2028 and U+2029 are
/// escaped too, because engines older than ES2019 reject them inside string
/// literals. `</script>` needs no escaping: native platforms evaluate the
/// script directly, without an HTML parser.
String buildMessageDispatchScript(String data) {
  final literal = jsonEncode(data)
      .replaceAll('\u2028', r'\u2028')
      .replaceAll('\u2029', r'\u2029');
  return 'window.dispatchEvent(new MessageEvent("message", '
      '{data: $literal}));';
}
