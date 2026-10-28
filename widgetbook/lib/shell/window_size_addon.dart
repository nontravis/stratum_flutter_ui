import 'package:stratum_ui/stratum_ui.dart';
import 'package:widgetbook/widgetbook.dart' hide ThemeMode;

/// The logical size the catalog gives each window size class; each size falls
/// inside its own class by `WindowSize.fromSize` (fo11/us02/fr01).
const Map<WindowSize, Size> catalogWindowSizes = {
  WindowSize.watch: Size(240, 240),
  WindowSize.mobile: Size(390, 844),
  WindowSize.tablet: Size(834, 1194),
  WindowSize.desktop: Size(1280, 800),
  WindowSize.bigDesktop: Size(1920, 1080),
};

/// The toolbar's window size setting: one viewport per [WindowSize], named
/// after it, frameless, starting on `mobile` (fo11/us02/fr01).
class WindowSizeAddon extends ViewportAddon {
  WindowSizeAddon()
    : super([
        for (final size in WindowSize.values)
          ViewportData(
            name: size.name,
            width: catalogWindowSizes[size]!.width,
            height: catalogWindowSizes[size]!.height,
            pixelRatio: 1,
            platform: defaultTargetPlatform,
          ),
      ], showFrame: false);

  /// `mobile`; Widgetbook's [ViewportAddon] starts on the first entry.
  @override
  ViewportData get initialValue => viewports.firstWhere(
    (viewport) => viewport.name == WindowSize.mobile.name,
  );
}
