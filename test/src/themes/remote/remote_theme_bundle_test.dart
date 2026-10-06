import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/themes/remote/remote_theme_bundle.dart';

class _Parent extends AssetBundle {
  final reads = <String>[];

  @override
  Future<ByteData> load(String key) async {
    reads.add(key);
    if (key == 'assets/a.txt') return ByteData.sublistView(utf8.encode('app'));
    throw FlutterError('Unable to load asset: "$key".');
  }

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    reads.add(key);
    if (key == 'assets/a.txt') return 'app';
    throw FlutterError('Unable to load asset: "$key".');
  }
}

void main() {
  test('d3: an installed folder serves its entries from memory', () async {
    final parent = _Parent();
    final bundle = RemoteThemeBundle(parent)
      ..add(RemoteThemeBundle.folderOf('brand', 1), {
        'theme.yaml': Uint8List.fromList(utf8.encode('name: brand')),
        'fonts/a.ttf': Uint8List.fromList([1, 2]),
      });

    expect(
      await bundle.loadString('stratum-remote/brand/1/theme.yaml'),
      'name: brand',
    );
    expect(
      (await bundle.load('stratum-remote/brand/1/fonts/a.ttf')).buffer
          .asUint8List(),
      [1, 2],
    );
    expect(parent.reads, isEmpty);
  });

  test('r12: an entry read as text takes the strict decode of install step '
      '9, failing at the byte where it stops', () async {
    final latin1 = Uint8List.fromList([
      ...utf8.encode('# caf'),
      0xE9,
      ...utf8.encode(' note'),
    ]);
    final bundle = RemoteThemeBundle(_Parent())
      ..add('stratum-remote/brand/1', {'theme.yaml': latin1});
    final stopsAt = isA<FormatException>().having((e) => e.offset, 'offset', 6);

    expect(() => RemoteThemeBundle.decodeText(latin1), throwsA(stopsAt));
    await expectLater(
      bundle.loadString('stratum-remote/brand/1/theme.yaml'),
      throwsA(stopsAt),
    );
  });

  test('r12: valid UTF-8 text reads back unchanged', () async {
    const thai = 'name: สงกรานต์';
    final bundle = RemoteThemeBundle(_Parent())
      ..add('stratum-remote/brand/1', {
        'theme.yaml': Uint8List.fromList(utf8.encode(thai)),
      });

    expect(
      RemoteThemeBundle.decodeText(Uint8List.fromList(utf8.encode(thai))),
      thai,
    );
    expect(await bundle.loadString('stratum-remote/brand/1/theme.yaml'), thai);
  });

  test('d3: every other key goes to the app bundle', () async {
    final parent = _Parent();
    final bundle = RemoteThemeBundle(parent);

    expect(await bundle.loadString('assets/a.txt'), 'app');
    expect(parent.reads, ['assets/a.txt']);
  });

  test('d3: a dropped folder serves nothing', () async {
    final bundle = RemoteThemeBundle(_Parent())
      ..add('stratum-remote/brand/1', {'theme.yaml': Uint8List(1)})
      ..remove('stratum-remote/brand/1');

    expect(bundle.holds('stratum-remote/brand/1'), isFalse);
    await expectLater(
      bundle.load('stratum-remote/brand/1/theme.yaml'),
      throwsA(isA<FlutterError>()),
    );
  });

  test('d3: a missing entry under a held folder fails, never reaching the '
      'app bundle', () async {
    final parent = _Parent();
    final bundle = RemoteThemeBundle(parent)..add('stratum-remote/brand/1', {});

    await expectLater(
      bundle.load('stratum-remote/brand/1/x.png'),
      throwsA(isA<FlutterError>()),
    );
    expect(parent.reads, isEmpty);
  });
}
