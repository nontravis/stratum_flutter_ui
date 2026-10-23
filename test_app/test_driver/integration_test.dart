import 'package:integration_test/integration_test_driver.dart';

/// Standard integration-test driver: web and profile Android run through
/// `flutter drive` with this driver. The response data carries the per-test
/// map the e2e round reads, on failure too.
Future<void> main() => integrationDriver(writeResponseOnFailure: true);
