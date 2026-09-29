import 'package:stratum_ui/src/src.dart';

class AppSystemUI {
  const AppSystemUI();

  static const SystemUiOverlayStyle light = SystemUiOverlayStyle(
    // Set status bar color
    statusBarColor: Colors.white,
    // Set status bar icon color
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFFF8FAFC),
    systemNavigationBarIconBrightness: Brightness.dark,
  );

  static const SystemUiOverlayStyle dark = SystemUiOverlayStyle(
    // Set status bar color
    statusBarColor: Colors.black,
    // Set status bar icon color
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: Color(0xFF121926),
    systemNavigationBarIconBrightness: Brightness.light,
  );
}
