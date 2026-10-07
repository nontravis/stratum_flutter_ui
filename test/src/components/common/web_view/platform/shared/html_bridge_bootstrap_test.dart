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

  group('placeBridgeBootstrap', () {
    test('us02/fr01/e02: one placement for the web and native scripts', () {
      const html = '<!-- a -->\n<!doctype html><p>Hi</p>';
      expect(
        placeBridgeBootstrap(html, '<script>x</script>'),
        '<!-- a -->\n<!doctype html><script>x</script><p>Hi</p>',
      );
      expect(
        placeBridgeBootstrap('<p>Hi</p>', '<script>x</script>'),
        '<script>x</script><p>Hi</p>',
      );
    });
  });

  group('injectNativeBridgeBootstrap', () {
    const nonce = '0123456789abcdef0123456789abcdef';
    const token = 'fedcba9876543210fedcba9876543210';

    String inject(String html) =>
        injectNativeBridgeBootstrap(html, nonce: nonce, token: token);

    test('us02/fr01/e02: goes right after a leading doctype, or first', () {
      expect(
        inject('<!DOCTYPE html><p>Hi</p>'),
        startsWith("<!DOCTYPE html><script>(function(){'use strict';"),
      );
      expect(
        inject('<p>Hi</p>'),
        startsWith("<script>(function(){'use strict';"),
      );
      expect(inject('<p>Hi</p>'), endsWith('})();</script><p>Hi</p>'));
    });

    test('us03/fr04: captures the platform bridge and replaces it with a '
        'frozen envelope sender', () {
      final html = inject('<p>Hi</p>');
      expect(html, contains('var b=window.StratumBridge;'));
      expect(html, contains('var p=b.postMessage;'));
      expect(
        html,
        contains("p.call(b,'$nativeBridgeEnvelopeTag$nonce:'+k+':'+d);"),
      );
      expect(html, contains("Object.defineProperty(window,'StratumBridge',"));
      expect(html, contains('Object.freeze({postMessage:function(d){'));
      expect(html, contains("s('message',String(d));"));
    });

    test('us03/fr04: posts hello with the nonce when it runs', () {
      expect(inject('<p>Hi</p>'), contains("s('hello','');"));
    });

    test('us03/fr04: keeps the outbound token in its own window property, '
        'never in an envelope', () {
      final html = inject('<p>Hi</p>');
      expect(
        html,
        contains(
          "Object.defineProperty(window,'$nativeBridgeTokenProperty',\n"
          "{value:'$token'});",
        ),
      );
      expect(token.allMatches(html), hasLength(1));
      expect(nonce.allMatches(html), hasLength(1));
    });

    test('us03/fr04: does nothing without a platform bridge', () {
      expect(
        inject('<p>Hi</p>'),
        contains("if(!b||typeof b.postMessage!=='function')return;"),
      );
    });

    test('nf01/NFR-Sec03: puts no secret in a URL, storage, a cookie, the '
        'window name, or the history state', () {
      final html = inject('<p>Hi</p>');
      for (final place in [
        'location',
        'window.name',
        'localStorage',
        'sessionStorage',
        'document.cookie',
        'history',
        'console',
      ]) {
        expect(html, isNot(contains(place)), reason: place);
      }
    });
  });
}
