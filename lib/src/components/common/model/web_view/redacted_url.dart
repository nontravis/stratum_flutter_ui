import 'package:freezed_annotation/freezed_annotation.dart' show internal;

/// Redacts [url] to its origin for safe logging (NFR-Sec06).
///
/// Returns `null` for a `null` [url]. With a host, returns the lowercase
/// `scheme://host[:port]` origin, plus a trailing `/…` when [url] carries
/// user info, a path other than empty or `/`, a query, or a fragment.
/// With no host, returns `<scheme>:…`, or `…` alone when [url] has no
/// scheme either.
@internal
String? redactedUrl(Uri? url) {
  if (url == null) return null;
  if (url.host.isEmpty) {
    return url.scheme.isEmpty ? '…' : '${url.scheme.toLowerCase()}:…';
  }
  final origin = Uri(
    scheme: url.scheme.toLowerCase(),
    host: url.host.toLowerCase(),
    port: url.port,
  ).toString();
  final cutRest =
      url.userInfo.isNotEmpty ||
      (url.path.isNotEmpty && url.path != '/') ||
      url.hasQuery ||
      url.hasFragment;
  return cutRest ? '$origin/…' : origin;
}
