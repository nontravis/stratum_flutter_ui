/// Returns the origin of [url]: lowercase scheme and host, plus the port.
///
/// Returns `null` when [url] is `null` or has no host, for example
/// `about:blank` or the opaque origin string `null`.
Uri? originOf(Uri? url) {
  if (url == null || url.host.isEmpty) return null;
  return Uri(
    scheme: url.scheme.toLowerCase(),
    host: url.host.toLowerCase(),
    port: url.port,
  );
}

/// Whether [origin] belongs to one of the [allowed] origins.
///
/// Entries match on scheme, host, and port. Host comparison ignores case, a
/// default port equals an explicit one (`https://a.com` matches
/// `https://a.com:443`), and path, query, and fragment are ignored. A `null`
/// or host-less [origin] never matches.
bool isAllowedOrigin(Uri? origin, Set<Uri> allowed) {
  final candidate = originOf(origin);
  if (candidate == null) return false;
  return allowed.any((entry) => originOf(entry) == candidate);
}
