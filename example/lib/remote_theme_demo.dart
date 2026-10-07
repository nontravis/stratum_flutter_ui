// The remote theme recipe (F-01 US-09): starts on theme "ocean" from a
// kept zip, installs theme "sunset" while it runs, and shows a refused zip.
//
//   flutter run -d <device> -t lib/remote_theme_demo.dart
//
// An app downloads each zip and fetches its checksum from its own API;
// this recipe reads the zips from its assets instead, so it needs no
// server, and Stratum UI itself downloads nothing (FO-04). Each zip was
// packed from the folder beside it by:
//
//   dart run stratum_ui:stratum_theme pack assets/remote_themes/<id> \
//     --out assets/remote_themes
import 'package:stratum_ui/stratum_ui.dart';
import 'package:stratum_ui_example/font_licenses.dart';

/// The checksum of `assets/remote_themes/ocean.zip`, as an app's API would
/// serve it.
const oceanChecksum =
    'sha256:'
    '73880efdb3c31880547bbfcac834b05d5ab688ad4a29bbb5b18f118175c124f4';

/// The checksum of `assets/remote_themes/sunset.zip`.
const sunsetChecksum =
    'sha256:'
    '83c45608f854e0e5d6fc6b1fd687a7a761f73c18d8eb121df6970e2eab9916f1';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  registerGoogleFontLicenses();
  final ocean = await rootBundle.load('assets/remote_themes/ocean.zip');
  final sunset = await rootBundle.load('assets/remote_themes/sunset.zip');
  // A kept zip installs at preload; one that fails is skipped and
  // reported, so the app deletes it and downloads it again.
  final controller = await StratumThemeController.preload(
    initialThemeId: 'ocean',
    remoteThemes: [
      StratumRemoteTheme(
        id: 'ocean',
        bytes: ocean.buffer.asUint8List(
          ocean.offsetInBytes,
          ocean.lengthInBytes,
        ),
        checksum: oceanChecksum,
      ),
    ],
    onRemoteThemeError: (id, error) =>
        debugPrint('kept zip $id refused: ${error.code.key}'),
  );
  runApp(
    RemoteThemeDemoApp(
      controller: controller,
      sunsetZip: sunset.buffer.asUint8List(
        sunset.offsetInBytes,
        sunset.lengthInBytes,
      ),
    ),
  );
}

/// The recipe on [controller], which preloaded ocean; [sunsetZip] is the
/// zip "Install sunset" hands over, as if the app had just downloaded it.
class RemoteThemeDemoApp extends StatelessWidget {
  const RemoteThemeDemoApp({
    super.key,
    required this.controller,
    required this.sunsetZip,
  });

  final StratumThemeController controller;
  final Uint8List sunsetZip;

  @override
  Widget build(BuildContext context) {
    return WidgetsApp(
      title: 'Stratum remote theme recipe',
      color: const Color(0xFF0E7490),
      debugShowCheckedModeBanner: false,
      builder: (context, child) => StratumThemeApplication.controlled(
        controller: controller,
        themeMode: ThemeMode.light,
        child: _RemoteThemePage(controller: controller, sunsetZip: sunsetZip),
      ),
    );
  }
}

class _RemoteThemePage extends StatefulWidget {
  const _RemoteThemePage({required this.controller, required this.sunsetZip});

  final StratumThemeController controller;
  final Uint8List sunsetZip;

  @override
  State<_RemoteThemePage> createState() => _RemoteThemePageState();
}

class _RemoteThemePageState extends State<_RemoteThemePage> {
  /// The last refusal as `<code>: <message>`, or null.
  String? _refusal;

  /// Installs sunset from its zip, then shows it: a theme the app
  /// downloaded while it runs.
  Future<void> _installSunset() async {
    await widget.controller.install(
      StratumRemoteTheme(
        id: 'sunset',
        bytes: widget.sunsetZip,
        checksum: sunsetChecksum,
      ),
    );
    await widget.controller.switchTo('sunset');
    if (mounted) setState(() => _refusal = null);
  }

  /// Hands over sunset's bytes with a checksum that does not match them:
  /// the install refuses the zip, and the theme on screen stays.
  Future<void> _installBroken() async {
    try {
      await widget.controller.install(
        StratumRemoteTheme(
          id: 'sunset',
          bytes: widget.sunsetZip,
          checksum: oceanChecksum,
        ),
      );
    } on StratumRemoteThemeException catch (error) {
      if (mounted) {
        setState(() => _refusal = '${error.code.key}: ${error.message}');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = StratumTextStyle.body.s16.build(context);
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) => ContainerLayout(
        style: const WidgetStyle(padding: EdgeInsets.all(24)),
        child: ColumnLayout(
          gap: 16,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Theme: ${widget.controller.activeId}', style: text),
            ContainerLayout(
              style: WidgetStyle(
                width: 48,
                height: 48,
                backgroundColor: context.theme.color.brand.normal,
              ),
            ),
            const StratumThemeAssetView.loading(width: 48, height: 48),
            _Button(
              label: 'Install sunset',
              onTap: _installSunset,
              style: text,
            ),
            _Button(
              label: 'Install broken zip',
              onTap: _installBroken,
              style: text,
            ),
            if (_refusal case final refusal?) Text(refusal, style: text),
          ],
        ),
      ),
    );
  }
}

/// A Stratum tap surface with a text label.
class _Button extends StatelessWidget {
  const _Button({
    required this.label,
    required this.onTap,
    required this.style,
  });

  final String label;
  final VoidCallback onTap;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return StratumInkWell(
      onTap: onTap,
      child: ContainerLayout(
        style: const WidgetStyle(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        child: Text(label, style: style),
      ),
    );
  }
}
