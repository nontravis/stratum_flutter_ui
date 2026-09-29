export 'package:stratum_ui/src/components/common/web_view/platform/platform_web_view_stub.dart'
    if (dart.library.js_interop) 'package:stratum_ui/src/components/common/web_view/platform/platform_web_view_web.dart'
    if (dart.library.io) 'package:stratum_ui/src/components/common/web_view/platform/platform_web_view_io.dart';
