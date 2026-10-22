/// Extracts the fixture id from launch arguments or the platform default route.
library;

/// Prefix every fixture route path starts with.
const String fixtureRoutePrefix = '/fixture/';

/// Returns the fixture id carried by [args] or [defaultRouteName].
///
/// A `--route=<path>` argument wins when present, even when its path lacks
/// [fixtureRoutePrefix]; a missing prefix yields null.
String? fixtureIdFrom({
  required List<String> args,
  required String defaultRouteName,
}) {
  final routeArg = args
      .where((arg) => arg.startsWith('--route='))
      .map((arg) => arg.substring('--route='.length))
      .firstOrNull;

  return _idAfterPrefix(routeArg ?? defaultRouteName);
}

String? _idAfterPrefix(String route) {
  if (!route.startsWith(fixtureRoutePrefix)) {
    return null;
  }
  final id = route.substring(fixtureRoutePrefix.length);
  return id.isEmpty ? null : id;
}
