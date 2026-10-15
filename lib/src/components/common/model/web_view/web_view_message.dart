import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:stratum_ui/src/themes/value_model.dart';

part 'generated/web_view_message.freezed.dart';

/// A message that the page sent through the bridge.
///
/// Answer it with `StratumWebViewController.reply`; only the controller
/// that delivered it accepts it.
@valueModel
abstract class StratumWebViewMessage with _$StratumWebViewMessage {
  const factory({
    /// Message payload. Encode structured data yourself, for example as JSON.
    required String data,

    /// Origin of the page that sent the message, which can differ from the
    /// page shown now, or `null` for HTML content loaded from a
    /// `StratumWebViewHtmlSource`.
    Uri? origin,
  }) = _StratumWebViewMessage;

  const new _();

  @override
  String toString() => 'StratumWebViewMessage(data: $data, origin: $origin)';
}
