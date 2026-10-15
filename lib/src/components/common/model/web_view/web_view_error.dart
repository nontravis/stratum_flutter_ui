import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:stratum_ui/src/themes/value_model.dart';

part 'generated/web_view_error.freezed.dart';

/// Kind of failure reported through `StratumWebView.onError`.
enum StratumWebViewErrorType {
  /// The page could not be reached: DNS, TLS, connection, or timeout.
  network,

  /// The server answered the page request with an HTTP error status.
  http,
}

/// A main-frame loading failure on a native platform.
@valueModel
abstract class StratumWebViewError with _$StratumWebViewError {
  const factory({
    /// Kind of failure.
    required StratumWebViewErrorType type,

    /// Human-readable description from the platform.
    required String description,

    /// Platform error code for [StratumWebViewErrorType.network], HTTP status
    /// for [StratumWebViewErrorType.http].
    int? code,

    /// Address that failed to load, when the platform reports it.
    Uri? url,
  }) = _StratumWebViewError;

  const new _();

  @override
  String toString() =>
      'StratumWebViewError(${type.name}, $code, $description, $url)';
}
