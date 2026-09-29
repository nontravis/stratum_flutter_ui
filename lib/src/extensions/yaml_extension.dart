import 'package:stratum_ui/src/src.dart';

extension AppYamlMapExtension on YamlMap {
  dynamic get<T>(String key) {
    final data = this[key];
    if (data == null) {
      throw UnimplementedError('Data at key $key is null.');
    }
    return data;
  }
}
