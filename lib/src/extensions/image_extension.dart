import 'package:stratum_ui/src/src.dart';

extension ImageExtension on AssetGenImage {}


extension StratumStringImageExtension on String {
  AssetImage toImage({
    AssetBundle? bundle,
    String? package,
  }) =>
      AssetImage(
        this,
        bundle: bundle,
        package: package,
      );

  Widget toImageWidget({
    double? width,
    double? height,
    BoxFit? fit,
  }) =>
      Image.asset(
        this,
        width: width,
        height: height,
        fit: fit,
      );
}