import 'dart:convert';

import 'package:stratum_ui/src/components/common/web_view/platform/shared/html_bridge_bootstrap.dart';
import 'package:stratum_ui/src/components/common/web_view/platform/shared/origin_policy.dart';

/// Builds the one native dispatch script (`s03_domain.md` invariant 15): a
/// strict-mode IIFE that delivers [data] to the page as a `message` event
/// and returns `true`, or dispatches nothing and returns `false`.
///
/// Before any data appears, the script checks the page it runs in: the
/// outbound [token] equals the page's [nativeBridgeTokenProperty] (`===`
/// against the literal, so a getter or a Proxy learns nothing), or
/// `window.location.origin` equals one of [allowedOrigins] (compared as
/// literals, so no page method runs). A `null` [token] leaves the token
/// branch out. An opaque-origin document reads `"null"`, which no entry
/// equals. The script never carries the inbound nonce.
///
/// [jsonEncode] turns [data] into a valid JavaScript string literal: quotes,
/// backslashes, and control characters are escaped. U+2028 and U+2029 are
/// escaped too, because engines older than ES2019 reject them inside string
/// literals. `</script>` needs no escaping: native platforms evaluate the
/// script directly, without an HTML parser.
String buildMessageDispatchScript(
  String data, {
  required String? token,
  required Iterable<Uri> allowedOrigins,
}) {
  final literal = jsonEncode(data)
      .replaceAll('\u2028', r'\u2028')
      .replaceAll('\u2029', r'\u2029');
  final origins = {
    for (final entry in allowedOrigins)
      if (originOf(entry) case final origin?) origin.toString(),
  };
  final checks = [
    if (token != null) "t==='$token'",
    for (final origin in origins) 'o===${jsonEncode(origin)}',
  ];
  final guard = checks.isEmpty ? 'false' : checks.join('||');
  return [
    "(function(){'use strict';var t,o;",
    'try{t=window.$nativeBridgeTokenProperty;}catch(e){}',
    'try{o=window.location.origin;}catch(e){}',
    'if(!($guard))return false;',
    'window.dispatchEvent(new MessageEvent("message",{data:$literal}));',
    'return true;})()',
  ].join();
}
