import 'package:stratum_ui/src/components/common/web_view/platform/shared/html_bridge_bootstrap.dart';

/// The inbound nonce that the native bootstrap in [html] carries.
String nonceIn(String html) =>
    RegExp('$nativeBridgeEnvelopeTag([0-9a-f]{32}):')
        .firstMatch(html)!
        .group(1)!;

/// The outbound token that the native bootstrap in [html] keeps.
String tokenIn(String html) =>
    RegExp(r"\{value:'([0-9a-f]{32})'\}").firstMatch(html)!.group(1)!;

/// A document id as the native bootstrap draws it: 32 lowercase hex.
const String documentA = '00112233445566778899aabbccddeeff';

/// The id of another document, such as the one a reload parses.
const String documentB = 'ffeeddccbbaa99887766554433221100';

/// A native bridge envelope of [kind] that carries [nonce] and [data], as
/// the bootstrap's wrapper sends it.
String envelope(String nonce, String kind, [String data = '']) =>
    '$nativeBridgeEnvelopeTag$nonce:$kind:$data';

/// A native `message` envelope that carries [nonce], the id of the
/// [document] that sent it, and [data], as the bootstrap's wrapper sends it.
String messageEnvelope(
  String nonce,
  String data, {
  String document = documentA,
}) => envelope(nonce, 'message', '$document:$data');
