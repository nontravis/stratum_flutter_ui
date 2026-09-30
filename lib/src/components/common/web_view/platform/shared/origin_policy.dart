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

/// Describes why [entry] can never match a page origin, or returns `null`
/// when it works as an allowlist entry.
///
/// Pages report http or https origins with an ASCII (punycode) host. An entry
/// without a scheme, with another scheme, or with a Unicode host (which
/// [Uri] percent-encodes instead of converting to punycode) never matches.
String? allowedOriginProblem(Uri entry) {
  if (!entry.isScheme('http') && !entry.isScheme('https')) {
    return '$entry needs an http or https scheme';
  }
  if (entry.host.isEmpty) return '$entry has no host';
  if (entry.host.contains('%')) {
    return '$entry has a non-ASCII host; use its punycode form (xn--…)';
  }
  return null;
}
