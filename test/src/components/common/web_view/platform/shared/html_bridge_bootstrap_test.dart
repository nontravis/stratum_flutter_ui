import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/components/common/web_view/platform/shared/html_bridge_bootstrap.dart';

void main() {
  group('injectBridgeBootstrap', () {
    test('inserts the script after a leading doctype', () {
      final result = injectBridgeBootstrap(
        '<!DOCTYPE html><p>Hi</p>',
        'abc123',
      );
      expect(result, startsWith('<!DOCTYPE html><script>(function(){'));
      expect(result, endsWith('<p>Hi</p>'));
    });

    test('matches the doctype case-insensitively with leading whitespace', () {
      final result = injectBridgeBootstrap(
        '  \n<!doctype HTML>\n<p>Hi</p>',
        'abc123',
      );
      expect(result, startsWith('  \n<!doctype HTML><script>(function(){'));
      expect(result, endsWith('<p>Hi</p>'));
    });

    test('matches the doctype after a leading HTML comment', () {
      final result = injectBridgeBootstrap(
        '<!-- generated -->\n<!DOCTYPE html><p>Hi</p>',
        'abc123',
      );
      expect(
        result,
        startsWith('<!-- generated -->\n<!DOCTYPE html><script>(function(){'),
      );
      expect(result, endsWith('<p>Hi</p>'));
    });

    test('matches the doctype after whitespace and a comment combined', () {
      final result = injectBridgeBootstrap(
        '  <!-- a -->\n  <!doctype html>\n<p>Hi</p>',
        'abc123',
      );
      expect(
        result,
        startsWith('  <!-- a -->\n  <!doctype html><script>(function(){'),
      );
      expect(result, endsWith('<p>Hi</p>'));
    });

    test('stays fast with many leading comments and no doctype', () {
      // A pattern that lets one comment end at any later `-->` backtracks
      // exponentially here; 22 comments already take seconds with it.
      final html = '${'<!---->' * 22}<p>Hi</p>';
      final stopwatch = Stopwatch()..start();
      final result = injectBridgeBootstrap(html, 'abc123');
      stopwatch.stop();
      expect(result, startsWith('<script>(function(){'));
      expect(stopwatch.elapsedMilliseconds, lessThan(100));
    });

    test('does not let a comment span markup to reach a later doctype', () {
      final result = injectBridgeBootstrap(
        '<!-- a --><p>x</p><!-- b --><!DOCTYPE html><p>Hi</p>',
        'abc123',
      );
      expect(result, startsWith('<script>(function(){'));
    });

    test('prepends the script when there is no doctype', () {
      final result = injectBridgeBootstrap('<p>Hi</p>', 'abc123');
      expect(result, startsWith('<script>(function(){'));
      expect(result, endsWith('<p>Hi</p>'));
    });

    test('embeds the nonce in the handshake string', () {
      final result = injectBridgeBootstrap('<p>Hi</p>', 'the-nonce');
      expect(result, contains("'stratum-bridge-handshake:the-nonce'"));
    });

    test('preserves the original HTML unchanged aside from the insertion', () {
      const html = '<!DOCTYPE html><p>one</p><p>two</p>';
      final result = injectBridgeBootstrap(html, 'n1');
      expect(
        result.replaceRange(
          '<!DOCTYPE html>'.length,
          result.indexOf('<p>one</p>'),
          '',
        ),
        html,
      );
    });
  });
}
