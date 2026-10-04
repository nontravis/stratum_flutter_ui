import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';
import 'package:stratum_ui/src/themes/theme_font_loader.dart';
import 'package:stratum_ui/src/themes/typography/google_fonts_lookup.dart';

import '../components/common/fakes/fake_stratum_theme.dart';
import 'config/theme_fixtures.dart' show layer;

/// The asset key of the package default theme file.
const packageDefaultKey =
    'packages/stratum_ui/assets/themes/default/theme.yaml';

/// The asset key of the app theme [id].
String themeKey(String id) => 'assets/themes/$id/theme.yaml';

/// The asset key of [fontTheme]'s font file when the theme [id] sets it.
String fontKey(String id) => 'assets/themes/$id/fonts/DBHeavent-Regular.ttf';

/// An app theme file: the `$schema` line, then [body].
String appTheme([String body = '']) => layer(body);

/// An app theme that adds the unused font key [mark], so a test can tell
/// which layers a theme set holds.
String markTheme(String mark) =>
    appTheme('typography:\n  fonts:\n    $mark: { family: $mark }');

/// An app theme whose font `brand` lists one file under the family
/// DB Heavent.
String fontTheme() => appTheme('''
typography:
  fonts:
    brand: { family: DB Heavent, files: [fonts/DBHeavent-Regular.ttf] }''');

/// An app theme with an unknown top-level key, which fails to parse.
String brokenTheme() => appTheme('spcae:\n  md: 12');

/// An asset bundle with the package default theme, the app themes
/// `themes` (id to file text), the font files `fonts`, and an asset
/// manifest that lists all of them plus `manifestOnly`.
///
/// Counts every read by key in [reads]; a read of a key in [hold] waits
/// until that completer completes.
class FakeThemeBundle extends AssetBundle {
  new({
    Map<String, String> themes = const {},
    Set<String> fonts = const {},
    Set<String> manifestOnly = const {},
    String? packageDefault,
  }) : _texts = {
         packageDefaultKey: packageDefault ?? defaultThemeSource,
         for (final MapEntry(:key, :value) in themes.entries)
           themeKey(key): value,
       },
       _fonts = fonts,
       _manifestOnly = manifestOnly;

  final Map<String, String> _texts;
  final Set<String> _fonts;
  final Set<String> _manifestOnly;

  /// How many times each key was read.
  final reads = <String, int>{};

  /// Keys whose reads wait until their completer completes.
  final hold = <String, Completer<void>>{};

  @override
  Future<ByteData> load(String key) async {
    if (key == 'AssetManifest.bin') {
      return const StandardMessageCodec().encodeMessage(<String, Object>{
        for (final asset in {..._texts.keys, ..._fonts, ..._manifestOnly})
          asset: <Object>[],
      })!;
    }
    await _read(key);
    if (_fonts.contains(key)) return ByteData(8);
    if (_texts[key] case final text?) {
      return ByteData.sublistView(utf8.encode(text));
    }
    throw FlutterError('Unable to load asset: "$key".');
  }

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    await _read(key);
    if (_texts[key] case final text?) return text;
    throw FlutterError('Unable to load asset: "$key".');
  }

  Future<void> _read(String key) async {
    reads[key] = (reads[key] ?? 0) + 1;
    await hold[key]?.future;
  }
}

/// The family and the file count of every font registration this test
/// makes; registers nothing in the engine.
List<(String, int)> recordFontLoads() {
  final loads = <(String, int)>[];
  ThemeFontLoader.load = (family, files) async {
    loads.add((family, files.length));
  };
  addTearDown(ThemeFontLoader.reset);
  return loads;
}

/// Every `debugPrint` message of this test.
List<String> captureDebugPrint() {
  final messages = <String>[];
  final saved = debugPrint;
  debugPrint = (message, {wrapWidth}) => messages.add(message ?? '');
  addTearDown(() => debugPrint = saved);
  return messages;
}

/// Records each Google family, weight, and style the code asks the seam
/// for; with [pending], the Google wait waits on it.
List<(String, FontWeight, FontStyle?)> recordGoogleFonts({
  Future<void> Function()? pending,
}) {
  final calls = <(String, FontWeight, FontStyle?)>[];
  final savedFamily = GoogleFontsLookup.family;
  final savedPending = GoogleFontsLookup.pending;
  GoogleFontsLookup.family = (name, {required weight, required style}) {
    calls.add((name, weight, style));
    return name;
  };
  if (pending != null) GoogleFontsLookup.pending = pending;
  addTearDown(() {
    GoogleFontsLookup.family = savedFamily;
    GoogleFontsLookup.pending = savedPending;
  });
  return calls;
}

/// Preloads a controller from [bundle] and collects each id it reports.
Future<(StratumThemeController, List<String>)> startController(
  FakeThemeBundle bundle, {
  String? initialThemeId,
}) async {
  final changes = <String>[];
  final controller = await StratumThemeController.preload(
    initialThemeId: initialThemeId,
    onThemeChanged: changes.add,
    bundle: bundle,
  );
  return (controller, changes);
}
