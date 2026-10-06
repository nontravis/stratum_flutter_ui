import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';
import 'package:stratum_ui/src/themes/remote/remote_theme_installer.dart';
import 'package:stratum_ui/src/themes/theme_font_loader.dart';
import 'package:stratum_ui/src/themes/theme_parse.dart';
import 'package:stratum_ui/src/themes/typography/google_fonts_lookup.dart';

import '../../components/common/fakes/default_theme_yaml.g.dart';
import 'remote_test_zip.dart';

/// The asset key of the package default theme file.
const remotePackageDefaultKey =
    'packages/stratum_ui/assets/themes/default/theme.yaml';

/// The package default theme as preload reads it, from the generated yaml
/// copy, so these fakes run on the web.
StratumThemeSource get remotePackageDefault => const StratumThemeSource(
  id: 'stratum-default',
  folder: 'packages/stratum_ui/assets/themes/default',
  yaml: defaultThemeYaml,
);

/// An app bundle with the package default theme and the app themes
/// `themes` (id to file text), with an asset manifest listing them; no
/// `dart:io`, so it runs on the web. Counts reads in [reads].
class RemoteFakeBundle extends AssetBundle {
  new({Map<String, String> themes = const {}})
    : _texts = {
        remotePackageDefaultKey: defaultThemeYaml,
        for (final MapEntry(:key, :value) in themes.entries)
          'assets/themes/$key/theme.yaml': value,
      };

  final Map<String, String> _texts;

  /// How many times each key was read.
  final reads = <String, int>{};

  ByteData get _manifest => const StandardMessageCodec().encodeMessage(
    <String, Object>{for (final asset in _texts.keys) asset: <Object>[]},
  )!;

  @override
  Future<ByteData> load(String key) async {
    if (key == 'AssetManifest.bin') return _manifest;
    reads[key] = (reads[key] ?? 0) + 1;
    if (_texts[key] case final text?) {
      return ByteData.sublistView(utf8.encode(text));
    }
    throw FlutterError('Unable to load asset: "$key".');
  }

  /// On the web, `AssetManifest.loadFromAssetBundle` reads
  /// `AssetManifest.bin.json`, the binary manifest as a base64 JSON string.
  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    if (key == 'AssetManifest.bin.json') {
      return json.encode(base64.encode(Uint8List.sublistView(_manifest)));
    }
    reads[key] = (reads[key] ?? 0) + 1;
    if (_texts[key] case final text?) return text;
    throw FlutterError('Unable to load asset: "$key".');
  }
}

/// A remote theme [id] whose zip holds `theme.yaml` (the `$schema` line,
/// then [body]) and [files] (path to bytes), all under [folder] when set,
/// with its true checksum.
StratumRemoteTheme remoteTheme(
  String id, {
  String body = '',
  Map<String, List<int>> files = const {},
  String? folder,
  int? maxBytes,
  int? maxEntries,
}) {
  final prefix = folder == null ? '' : '$folder/';
  final bytes = buildZip([
    ZipEntryFixture(
      '${prefix}theme.yaml',
      utf8.encode('$remoteSchemaLine\n$body'),
    ),
    for (final MapEntry(:key, :value) in files.entries)
      ZipEntryFixture('$prefix$key', value),
  ]);
  return StratumRemoteTheme(
    id: id,
    bytes: bytes,
    checksum: checksumOf(bytes),
    maxBytes: maxBytes ?? StratumRemoteTheme.defaultMaxBytes,
    maxEntries: maxEntries ?? StratumRemoteTheme.defaultMaxEntries,
  );
}

/// A remote theme [id] whose `theme.yaml` line 2 is `# caf`, the Latin-1
/// byte 0xE9, and ` note`: not valid UTF-8 at line 2, column 7, where
/// strict decoding stops.
StratumRemoteTheme latin1Theme(String id) {
  final bytes = buildZip([
    ZipEntryFixture('theme.yaml', [
      ...utf8.encode('$remoteSchemaLine\n# caf'),
      0xE9,
      ...utf8.encode(' note\n'),
    ]),
  ]);
  return StratumRemoteTheme(id: id, bytes: bytes, checksum: checksumOf(bytes));
}

/// The family and file count of every font registration; registers
/// nothing in the engine. Resets the generations and registrations after
/// the test.
List<(String, int)> recordRemoteFontLoads() {
  final loads = <(String, int)>[];
  ThemeFontLoader.load = (family, files) async {
    loads.add((family, files.length));
  };
  addTearDown(() {
    ThemeFontLoader.reset();
    RemoteThemeInstaller.reset();
  });
  return loads;
}

/// Every Google family name the code asks for; its wait completes at once.
List<String> recordRemoteGoogleFonts() {
  final names = <String>[];
  final savedFamily = GoogleFontsLookup.family;
  final savedPending = GoogleFontsLookup.pending;
  final savedExists = GoogleFontsLookup.exists;
  GoogleFontsLookup.family = (name, {required weight, required style}) {
    names.add(name);
    return name;
  };
  GoogleFontsLookup.pending = () async {};
  GoogleFontsLookup.exists = (name) => true;
  addTearDown(() {
    GoogleFontsLookup.family = savedFamily;
    GoogleFontsLookup.pending = savedPending;
    GoogleFontsLookup.exists = savedExists;
  });
  return names;
}

/// Every `debugPrint` message of this test.
List<String> captureRemoteLogs() {
  final messages = <String>[];
  final saved = debugPrint;
  debugPrint = (message, {wrapWidth}) => messages.add(message ?? '');
  addTearDown(() => debugPrint = saved);
  return messages;
}

/// Parses on the calling isolate for this test, as `fakeAsync` and the web
/// need.
void useSyncParse() {
  ThemeParse.run = (base, layers) async =>
      StratumThemeConfig.parse(base: base, layers: layers);
  addTearDown(ThemeParse.reset);
}
