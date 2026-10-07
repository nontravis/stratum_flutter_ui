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

    test('us03/fr04/e12, us02/fr01/e02, us03/fr03/e04: a comment the HTML '
        'tokenizer ends early keeps a later doctype from leading, so the '
        'bootstrap goes first', () {
      for (final html in [
        '<!--x--!><script>A</script><!---->\n<!doctype html><p>Hi</p>',
        '<!--><script>A</script><!---->\n<!doctype html><p>Hi</p>',
        '<!---><script>A</script><!---->\n<!doctype html><p>Hi</p>',
      ]) {
        expect(
          placeBridgeBootstrap(html, '<script>x</script>'),
          '<script>x</script>$html',
          reason: html,
        );
      }
    });

    test('us03/fr04/e12, us02/fr01/e02: every comment end the HTML '
        'tokenizer accepts keeps the bootstrap after the doctype', () {
      for (final comment in [
        '<!-- a -->',
        '<!---->',
        '<!-- b --->',
        '<!-->',
        '<!--->',
        '<!-- c --!>',
        '<!-- d --!-->',
      ]) {
        expect(
          placeBridgeBootstrap(
            '$comment\n<!doctype html><p>Hi</p>',
            '<script>x</script>',
          ),
          '$comment\n<!doctype html><script>x</script><p>Hi</p>',
          reason: comment,
        );
      }
    });

    test('us02/fr01/e02: stays linear over 20 000 comments of every end '
        'form with no doctype', () {
      final html = '${'<!----><!--><!---><!--a--!>' * 5000}<p>Hi</p>';
      final stopwatch = Stopwatch()..start();
      final result = placeBridgeBootstrap(html, '<script>x</script>');
      stopwatch.stop();
      expect(result, '<script>x</script>$html');
      expect(stopwatch.elapsedMilliseconds, lessThan(1000));
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

    test('us03/fr04/e11, nf01/NFR-Sec03: removes its own script element '
        'before anything else, so no secret stays in the live DOM', () {
      expect(
        inject('<p>Hi</p>'),
        startsWith(
          "<script>(function(){'use strict';\n"
          'var e=document.currentScript;if(e)e.remove();\n'
          'var b=window.StratumBridge;\n',
        ),
      );
    });

    test('us03/fr04/e11: binds the platform sender and String once, and '
        'sends only through those bindings', () {
      final html = inject('<p>Hi</p>');
      expect(html, contains('var send=b.postMessage.bind(b),S=String;'));
      expect(
        html,
        contains("send('$nativeBridgeEnvelopeTag$nonce:'+k+':'+d);"),
      );
      expect(html, contains("s('message',S(d));"));
      expect(html, isNot(contains('.call(')));
      expect(html, isNot(contains('.apply(')));
      expect(RegExp(r'\bString\b').allMatches(html), hasLength(1));
    });

    test('us03/fr04/e11: defines StratumBridge as a frozen envelope sender, '
        'non-writable and non-configurable', () {
      expect(
        inject('<p>Hi</p>'),
        contains(
          "Object.defineProperty(window,'StratumBridge',\n"
          '{value:Object.freeze({postMessage:function(d){\n'
          "s('message',S(d));}}),\n"
          'enumerable:true,writable:false,configurable:false});',
        ),
      );
    });

    test('us03/fr04: draws a 16-byte document id from crypto.getRandomValues '
        'in lowercase hex and posts hello with it last', () {
      final html = inject('<p>Hi</p>');
      expect(
        html,
        contains("var a=crypto.getRandomValues(new Uint8Array(16)),id='';"),
      );
      expect(
        html,
        contains('for(var i=0;i<16;i++)id+=(a[i]|256).toString(16).slice(1);'),
      );
      expect(html, endsWith("s('hello',id);\n})();</script><p>Hi</p>"));
    });

    test('us03/fr04/e10: posts bye with its document id on pagehide, in a '
        'capture listener added before any page script', () {
      expect(
        inject('<p>Hi</p>'),
        contains(
          "window.addEventListener('pagehide',function(){\n"
          "s('bye',id);},true);",
        ),
      );
    });

    test('us03/fr04/e14: posts bye once the document root is replaced in '
        'place, through an observer and a parentNode getter bound before '
        'any page script', () {
      final html = inject('<p>Hi</p>');
      expect(
        html,
        contains(
          'var doc=document,root=doc.documentElement,\n'
          'parentOf=Function.prototype.call.bind(\n'
          "Object.getOwnPropertyDescriptor(Node.prototype,'parentNode').get);\n"
          'new MutationObserver(function(){\n'
          "if(parentOf(root)!==doc)s('bye',id);})\n"
          '.observe(doc,{childList:true});\n',
        ),
      );
      expect(
        html.indexOf('new MutationObserver('),
        lessThan(html.indexOf("s('hello',id);\n})();")),
      );
    });

    test('us03/fr04/e03: posts hello again with the same document id on a '
        'pageshow that restores the document from the back-forward '
        'cache', () {
      expect(
        inject('<p>Hi</p>'),
        contains(
          "window.addEventListener('pageshow',function(v){\n"
          "if(v.persisted)s('hello',id);},true);",
        ),
      );
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
