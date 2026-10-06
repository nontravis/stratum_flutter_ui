import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The overlay asset bundle of FO-04 (design D3): serves the entries of
/// each installed theme zip from memory under
/// `stratum-remote/<id>/<generation>/<path>`, and hands every other key to
/// [parent], the app bundle, so FO-03's theme read, font registration, and
/// asset views run on a remote theme unchanged. Internal: not exported.
class RemoteThemeBundle extends AssetBundle {
  new(this.parent);

  /// The first segment of every key this bundle serves from memory.
  static const root = 'stratum-remote';

  /// The folder of install [generation] of [id].
  static String folderOf(String id, int generation) => '$root/$id/$generation';

  /// Decodes a zip entry as strict UTF-8: the one text decode of install
  /// step 9 and of every later read, so a theme that installed always
  /// reads again (FO-04 s03 invariant 4).
  ///
  /// Throws [FormatException] whose `offset` is the byte where decoding
  /// stops.
  static String decodeText(Uint8List bytes) => utf8.decode(bytes);

  /// The app bundle every other key goes to.
  final AssetBundle parent;

  final _folders = <String, Map<String, Uint8List>>{};

  /// Serves [entries], keyed by their path relative to the theme root,
  /// under [folder].
  void add(String folder, Map<String, Uint8List> entries) =>
      _folders[folder] = Map.unmodifiable(entries);

  /// Drops [folder] and its entries from memory.
  void remove(String folder) => _folders.remove(folder);

  /// Whether [folder] is in memory.
  bool holds(String folder) => _folders.containsKey(folder);

  /// Drops every folder.
  @override
  void clear() => _folders.clear();

  Uint8List? _entry(String key) {
    if (!key.startsWith('$root/')) return null;
    final parts = key.split('/');
    if (parts.length < 4) throw FlutterError('Unable to load asset: "$key".');
    final folder = parts.take(3).join('/');
    final entries = _folders[folder];
    final data = entries?[parts.skip(3).join('/')];
    if (data == null) throw FlutterError('Unable to load asset: "$key".');
    return data;
  }

  @override
  Future<ByteData> load(String key) async {
    final data = _entry(key);
    if (data == null) return parent.load(key);
    return ByteData.sublistView(data);
  }

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    final data = _entry(key);
    if (data == null) return parent.loadString(key, cache: cache);
    return decodeText(data);
  }

  @override
  Future<T> loadStructuredData<T>(
    String key,
    Future<T> Function(String value) parser,
  ) => parent.loadStructuredData(key, parser);

  @override
  Future<T> loadStructuredBinaryData<T>(
    String key,
    FutureOr<T> Function(ByteData data) parser,
  ) => parent.loadStructuredBinaryData(key, parser);

  @override
  void evict(String key) => parent.evict(key);
}
