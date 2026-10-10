import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';

void main() {
  group('n1/q8: the source models are freezed', () {
    test('StratumThemeSource gains copyWith and keeps its toString', () {
      const source = StratumThemeSource(
        id: 'brand',
        folder: 'assets/themes/brand',
        yaml: 'name: a',
      );

      final copy = source.copyWith(yaml: 'name: b');

      expect(
        copy,
        const StratumThemeSource(
          id: 'brand',
          folder: 'assets/themes/brand',
          yaml: 'name: b',
        ),
      );
      expect(
        copy.toString(),
        'StratumThemeSource(id: brand, folder: assets/themes/brand)',
      );
    });

    test('StratumThemeAsset gains copyWith and keeps its toString', () {
      const asset = StratumThemeAsset(
        kind: StratumAssetKind.svg,
        path: 'theme/a.svg',
      );

      expect(
        asset.copyWith(path: 'theme/b.svg'),
        const StratumThemeAsset(
          kind: StratumAssetKind.svg,
          path: 'theme/b.svg',
        ),
      );
      expect(
        asset.toString(),
        'StratumThemeAsset(kind: svg, path: theme/a.svg)',
      );
    });

    test('StratumSchemaVersion gains copyWith and keeps its text', () {
      final next = StratumSchemaVersion.current.copyWith(patch: 7);

      expect(next.toString(), 'stratum-theme/v1.1.7');
      expect(next.isSupported, isTrue);
      expect(
        StratumSchemaVersion.current.copyWith(minor: 2).isSupported,
        isFalse,
      );
    });

    test('StratumThemeFormatError gains copyWith and keeps its toString', () {
      const error = StratumThemeFormatError(
        code: StratumThemeErrorCode.required,
        source: 'brand',
        path: 'name',
        message: 'required',
        line: 2,
        column: 1,
      );

      expect(
        error.copyWith(line: null, column: null),
        const StratumThemeFormatError(
          code: StratumThemeErrorCode.required,
          source: 'brand',
          path: 'name',
          message: 'required',
        ),
      );
      expect(error.toString(), 'name: required');
    });

    test('StratumThemeFormatException keeps list equality and its text', () {
      const error = StratumThemeFormatError(
        code: StratumThemeErrorCode.required,
        source: 'brand',
        path: '',
        message: 'required',
      );

      expect(
        const StratumThemeFormatException([error]),
        StratumThemeFormatException(List.of([error])),
      );
      expect(
        const StratumThemeFormatException([error]).toString(),
        'StratumThemeFormatException: 1 problem(s) in theme.yaml\n'
        '  brand (root): required [required]',
      );
    });
  });
}
