import 'dart:async';

import 'package:stratum_ui/src/themes/config/escape_text.dart';
import 'package:yaml/yaml.dart';

/// The most UTF-16 code units a yaml text may hold (FO-01 US-01 FR-01
/// E07): 1 MiB.
const int yamlTextMaxUnits = 1048576;

/// The deepest nesting of collections a yaml text may hold, block or
/// flow, the root collection counting as 1 (FO-01 US-01 FR-01 E07).
const int yamlMaxDepth = 64;

/// The message of a refused anchor, alias, or tag (FO-01 US-01 FR-01 E07).
const yamlPropertyMessage =
    'no anchor, alias, or tag; refer to a token with "{path}" instead';

/// The message of nesting past [yamlMaxDepth] (FO-01 US-01 FR-01 E07).
const yamlDepthMessage = 'nesting deeper than 64';

/// The message of a text past [yamlTextMaxUnits] (FO-01 US-01 FR-01 E07).
const yamlSizeMessage = 'text longer than 1 MiB';

/// The message of a mapping key that is a collection or an explicit `?`
/// key (FO-01 US-01 FR-01 E07, design G9).
const yamlKeyMessage =
    'a mapping key is a collection or an explicit "?" key; write it as a '
    'plain or quoted value';

/// The message of a byte-order mark anywhere but the text's first
/// character (FO-01 US-01 FR-01 E07, design G4; security review round 2
/// C1).
const yamlBomMessage =
    'a byte-order mark only starts the text, never a later line';

const _tab = 0x09;
const _lf = 0x0A;
const _cr = 0x0D;
const _space = 0x20;
const _bang = 0x21;
const _quote = 0x22;
const _hash = 0x23;
const _percent = 0x25;
const _amp = 0x26;
const _apostrophe = 0x27;
const _star = 0x2A;
const _plus = 0x2B;
const _comma = 0x2C;
const _dash = 0x2D;
const _dot = 0x2E;
const _colon = 0x3A;
const _gt = 0x3E;
const _question = 0x3F;
const _at = 0x40;
const _openSquare = 0x5B;
const _backslash = 0x5C;
const _closeSquare = 0x5D;
const _grave = 0x60;
const _openCurly = 0x7B;
const _bar = 0x7C;
const _closeCurly = 0x7D;
const _nel = 0x85;
const _bom = 0xFEFF;

/// Loads [text] as one yaml document, in the one place that turns every
/// failure on hostile text into [YamlTextFailure] instead of an unhandled
/// exception (FO-01 US-01 FR-01 E07; FO-04 US-02 FR-03 E09, s05 exit 66).
///
/// [checkYamlGate] runs first, so no text past 1 MiB, nested past 64,
/// holding an anchor, an alias, or a tag, or using a collection or an
/// explicit `?` key as a mapping key reaches package:yaml, whose
/// `deepHashCode` takes time exponential in a collection key's nesting
/// (design RZ7); a tag never does, so package:yaml's `ArgumentError` on a
/// malformed tag cannot arise. package:yaml then loads under a zone that
/// drops every `print`: its default `yamlWarningCallback` prints the raw
/// source line of a spec-level warning, so an unfenced call lets a hostile
/// document put a raw control character on this process's real stdout
/// (sec f1/e02); the global callback itself is never written.
/// [StackOverflowError] is not caught: the depth cap leaves it
/// unreachable. Then [checkYamlTree] walks the loaded tree.
YamlNode loadYamlText(String text) {
  checkYamlGate(text);
  final YamlNode root;
  try {
    root = runZoned(
      () => loadYamlNode(text),
      zoneSpecification: ZoneSpecification(
        print: (self, parent, zone, line) {},
      ),
    );
  } on FormatException catch (error) {
    // `FormatException` also covers `YamlException` and
    // `StringScannerException`; `FormatException.offset` already carries
    // their span's start as a code-unit index with no new import, so
    // [_refusal] locates it exactly as it locates a gate refusal, and is
    // null when package:yaml found no position.
    final offset = error.offset;
    throw offset == null
        ? YamlTextFailure(escapeZipText(error.message))
        : _refusal(text, offset, escapeZipText(error.message));
  }
  checkYamlTree(root);
  return root;
}

/// Refuses a loaded tree (design G5 and G9, defence in depth behind
/// [checkYamlGate]): a node reached twice, which only an alias makes; a
/// mapping whose key node is a collection; and a collection nested deeper
/// than [yamlMaxDepth]. Walks with its own stack, so no depth can
/// overflow the call stack. Throws [YamlTextFailure] at the node's span.
void checkYamlTree(YamlNode root) {
  final seen = Set<YamlNode>.identity();
  final pending = <(YamlNode, int)>[(root, 0)];
  while (pending.isNotEmpty) {
    final (node, above) = pending.removeLast();
    if (!seen.add(node)) throw _nodeFailure(node, yamlPropertyMessage);
    final depth = node is YamlScalar ? above : above + 1;
    if (depth > yamlMaxDepth) throw _nodeFailure(node, yamlDepthMessage);
    if (node is YamlMap) {
      for (final MapEntry(:key, :value) in node.nodes.entries) {
        if (key is YamlNode) {
          if (key is! YamlScalar) throw _nodeFailure(key, yamlKeyMessage);
          pending.add((key, depth));
        }
        pending.add((value, depth));
      }
    } else if (node is YamlList) {
      for (final child in node.nodes) {
        pending.add((child, depth));
      }
    }
  }
}

/// [message] at [node]'s span start, 1-based.
YamlTextFailure _nodeFailure(YamlNode node, String message) {
  final start = node.span.start;
  return YamlTextFailure(
    message,
    at: (line: start.line + 1, column: start.column + 1),
  );
}

/// Refuses [text] before package:yaml reads it (FO-01 US-01 FR-01 E07,
/// design G1 to G4, G9): a text longer than [yamlTextMaxUnits] code
/// units; a YAML anchor, alias, or tag where package:yaml could start a
/// token, outside a comment; a mapping key that is a collection or an
/// explicit `?` key; a byte-order mark anywhere but the first character;
/// and nesting deeper than [yamlMaxDepth]. One linear pass that errs
/// toward refusing: it never passes a text in which package:yaml 3.1.4
/// reads an anchor, an alias, a tag, or a collection as a mapping key, or
/// nests past 64, and may refuse a text package:yaml would read. Throws
/// [YamlTextFailure] at the first offending character, with its 1-based
/// line and column and the message of its rule.
void checkYamlGate(String text) {
  if (text.length > yamlTextMaxUnits) {
    throw _refusal(text, yamlTextMaxUnits, yamlSizeMessage);
  }
  _YamlGate(text).run();
}

/// [message] at the code unit [index] of [text], its line and column
/// counted as package:yaml's spans count them: a line feed, a carriage
/// return and line feed, and a lone carriage return each end a line.
YamlTextFailure _refusal(String text, int index, String message) {
  var line = 1;
  var lineStart = 0;
  for (var i = 0; i < index; i++) {
    final unit = text.codeUnitAt(i);
    final crlf =
        unit == _cr && i + 1 < text.length && text.codeUnitAt(i + 1) == _lf;
    if (unit == _lf || (unit == _cr && !crlf)) {
      line++;
      lineStart = i + 1;
    }
  }
  return YamlTextFailure(
    message,
    at: (line: line, column: index - lineStart + 1),
  );
}

/// A yaml document [loadYamlText] could not parse: [message] is escaped
/// once (plan D-g); [at] is the 1-based line and column of the offending
/// character, or null when package:yaml found none.
final class YamlTextFailure implements Exception {
  const new(this.message, {this.at});

  final String message;
  final ({int line, int column})? at;
}

/// What a line left open for the next one.
enum _Open { none, quote, plain, blockScalar }

/// A rule of the model broke at the code unit [index]: nesting past
/// [yamlMaxDepth], or a mapping key that is a collection or an explicit
/// `?` key; [message] names it.
final class _Breach implements Exception {
  const new(this.index, this.message);

  final int index;
  final String message;
}

/// The pass of [checkYamlGate] after the size cap (design G2 to G4, G9):
/// per line, the property rule, and the depth model with the
/// collection-key rule, of the plan's rule table. The model mirrors
/// package:yaml 3.1.4's scanner for the constructs a theme file uses and
/// locks on any other; after the lock it adds a level for every line,
/// block indicator, key, and flow opener and never takes one away, so it
/// can only over-count. The collection-key rule refuses, before the lock
/// and after it, and never locks.
final class _YamlGate {
  new(this._text);

  final String _text;

  /// The column of each open block collection, innermost last; whether it
  /// is a mapping; and whether an indentless sequence sits on it.
  final _columns = <int>[];
  final _mappings = <bool>[];
  final _indentless = <bool>[];
  var _indentlessCount = 0;

  /// The index of the `[` or `{` of each open flow collection, innermost
  /// last.
  final _flowStarts = <int>[];

  /// Whether each open flow collection, innermost last, is a mapping
  /// (`{`) rather than a sequence (`[`).
  final _flowMaps = <bool>[];

  /// Whether the next node of each open flow collection, innermost last,
  /// sits in key position: right after its `{` or a `,`, until a `:`
  /// value indicator (design G9). Unused for a sequence.
  final _flowKeys = <bool>[];

  /// The `[` or `{` of the flow collection that closed last, while only
  /// blanks, comments, and line breaks followed it; else -1.
  var _flowEnd = -1;

  /// The last significant character seen after the lock: refuses a `[`
  /// or `{` right after a `{` or `,` the same way the unlocked path does
  /// (design G9), since the locked model no longer tracks which open
  /// collection is a mapping.
  var _lockedLast = -1;

  /// The last `]` or `}` after the lock, while only blanks, comments, and
  /// line breaks followed it; else -1.
  var _lockedClose = -1;
  var _locked = false;
  var _lockedCount = 0;
  _Open _open = _Open.none;
  var _openQuote = 0;
  var _plainMin = 0;
  var _scalarIndent = 0;
  var _scalarParent = 0;
  var _scalarMax = 0;
  var _content = false;
  var _afterScalar = false;
  var _flowKeyColumn = -1;

  int get _flow => _flowStarts.length;

  int get _depth => _columns.length + _indentlessCount + _flow + _lockedCount;

  /// Runs the property rule and the depth model over each line.
  void run() {
    final text = _text;
    var start = 0;
    while (true) {
      var end = start;
      while (end < text.length) {
        final unit = text.codeUnitAt(end);
        if (unit == _lf || unit == _cr) break;
        end++;
      }
      _line(start, end);
      if (end >= text.length) return;
      start = end + 1;
      if (text.codeUnitAt(end) == _cr &&
          start < text.length &&
          text.codeUnitAt(start) == _lf) {
        start++;
      }
    }
  }

  void _line(int start, int end) {
    var index = _propertyAt(start, end);
    var message = yamlPropertyMessage;
    final bom = _bomAt(start, end);
    if (bom >= 0 && (index < 0 || bom < index)) {
      index = bom;
      message = yamlBomMessage;
    }
    try {
      if (_locked) {
        _lockedLine(start, end, start);
      } else {
        _modelLine(start, end);
      }
    } on _Breach catch (breach) {
      if (index < 0 || breach.index < index) {
        throw _refusal(_text, breach.index, breach.message);
      }
    }
    if (index >= 0) throw _refusal(_text, index, message);
  }

  /// The first U+FEFF from [start] to [end] other than at the text's
  /// absolute index 0, where it is the text's own leading mark; -1 when
  /// none. package:yaml also allows a byte-order mark to start any later
  /// line (`scanner.dart`'s `_scanToNextToken`), a construct the model
  /// does not track, so the gate refuses every other one (design G4;
  /// security review round 2 C1).
  int _bomAt(int start, int end) {
    for (var i = start; i < end; i++) {
      if (_text.codeUnitAt(i) == _bom && i != 0) return i;
    }
    return -1;
  }

  // MARK: - The property rule (G3)

  /// The first `&`, `*`, or `!` from [start] to [end], outside the comment
  /// [_commentAt] proves, where package:yaml could start an anchor, an
  /// alias, or a tag; -1 when none. `&` and `*` count only before a
  /// character that can begin a name.
  int _propertyAt(int start, int end) {
    final stop = _commentAt(start, end);
    for (var i = start; i < stop; i++) {
      final unit = _text.codeUnitAt(i);
      if (unit != _amp && unit != _star && unit != _bang) continue;
      if (i > start && !_endsToken(_text.codeUnitAt(i - 1))) continue;
      if (unit == _bang || (i + 1 < end && !_blank(_text.codeUnitAt(i + 1)))) {
        return i;
      }
    }
    return -1;
  }

  /// The first `#` at the line's start or after a blank or U+FEFF with no
  /// `"` or `'` after it on the line, or [end]: package:yaml reads the
  /// rest of the line from there as a comment, or as scalar content that
  /// does not close on this line.
  int _commentAt(int start, int end) {
    var at = end;
    var quoteAfter = false;
    for (var i = end - 1; i >= start; i--) {
      final unit = _text.codeUnitAt(i);
      if (unit == _hash &&
          !quoteAfter &&
          (i == start ||
              _blank(_text.codeUnitAt(i - 1)) ||
              _text.codeUnitAt(i - 1) == _bom)) {
        at = i;
      }
      if (unit == _quote || unit == _apostrophe) quoteAfter = true;
    }
    return at;
  }

  /// Whether package:yaml may start a token right after [unit]: unless it
  /// is printable ASCII other than an indicator, or a standard character
  /// past U+009F other than U+FEFF, U+2028, and U+2029.
  static bool _endsToken(int unit) {
    if (unit > _space && unit < 0x7F) {
      return const [
        _openSquare,
        _closeSquare,
        _openCurly,
        _closeCurly,
        _comma,
        _colon,
        _quote,
        _apostrophe,
        _question,
        _dash,
        _bar,
        _gt,
      ].contains(unit);
    }
    if (unit >= 0xA0 && unit < 0xD800) return unit == 0x2028 || unit == 0x2029;
    if (unit >= 0xE000 && unit <= 0xFFFD) return unit == _bom;
    return true;
  }

  // MARK: - The depth model (G2)

  void _modelLine(int start, int end) {
    _flowKeyColumn = -1;
    if (_open == _Open.quote) {
      final close = _closeQuote(start, end, _openQuote);
      if (close < 0) return;
      _open = _Open.none;
      _afterScalar = true;
      _flowEnd = -1;
      _tokens(close, start, end);
      return;
    }
    if (_open == _Open.blockScalar) {
      if (_inBlockScalar(start, end)) return;
      _open = _Open.none;
    }
    var first = start;
    if (start == 0 && first < end && _text.codeUnitAt(first) == _bom) first++;
    while (first < end) {
      final unit = _text.codeUnitAt(first);
      if (unit != _space && (_flow == 0 || unit != _tab)) break;
      first++;
    }
    if (first >= end) return;
    final unit = _text.codeUnitAt(first);
    if (unit == _hash) {
      _open = _Open.none;
      return;
    }
    if (unit == _tab) {
      _lock(start, start, end);
      return;
    }
    final column = first - start;
    if (_open == _Open.plain) {
      _open = _Open.none;
      if ((_flow > 0 || column >= _plainMin) &&
          !(column == 0 && _documentMarker(first, end)) &&
          _plainCharAt(first, end)) {
        _continuePlain(first, start, end);
        return;
      }
    }
    if (_flow == 0) {
      while (_columns.isNotEmpty && _columns.last > column) {
        _pop();
      }
      if (column == 0 && unit == _percent) {
        if (_content) _lock(first, start, end);
        return;
      }
      if (column == 0 && _documentMarker(first, end)) {
        if (unit == _dot) {
          _lock(first, start, end);
          return;
        }
        _content = true;
        _tokens(first + 3, start, end);
        return;
      }
    }
    _tokens(first, start, end);
  }

  /// The tokens of one line from [from], dispatched as package:yaml's
  /// `_fetchNextToken` dispatches them.
  void _tokens(int from, int start, int end) {
    var i = from;
    while (true) {
      while (i < end && _blank(_text.codeUnitAt(i))) {
        i++;
      }
      if (i >= end) return;
      final unit = _text.codeUnitAt(i);
      if (unit == _hash) return;
      _content = true;
      final column = i - start;
      if (unit == _question && !_plainSafeAt(i + 1, end)) {
        throw _Breach(i, yamlKeyMessage);
      }
      if (_flow == 0) {
        final blankAfter = _blankOrEnd(i + 1, end);
        if (unit == _dash && blankAfter) {
          _entry(column, i);
          i++;
          continue;
        }
        if (unit == _colon && blankAfter && _flowKeyColumn >= 0) {
          throw _Breach(start + _flowKeyColumn, yamlKeyMessage);
        }
        if (unit == _bar || unit == _gt) {
          _blockScalarHeader(i, start, end);
          return;
        }
        if ((unit == _colon && blankAfter) ||
            unit == _comma ||
            unit == _closeSquare ||
            unit == _closeCurly) {
          _lock(i, start, end);
          return;
        }
      }
      switch (unit) {
        case _openSquare || _openCurly:
          if (_flow == 0) {
            _flowKeyColumn = column;
          } else if (_flowMaps.last && _flowKeys.last) {
            // design G9: this collection opens in its parent flow
            // mapping's key position (right after `{` or `,`).
            throw _Breach(i, yamlKeyMessage);
          }
          _flowMaps.add(unit == _openCurly);
          _flowKeys.add(true);
          _flowStarts.add(i);
          _check(i);
          _afterScalar = false;
          _flowEnd = -1;
          i++;
          continue;
        case _closeSquare || _closeCurly:
          _flowMaps.removeLast();
          _flowKeys.removeLast();
          _flowEnd = _flowStarts.removeLast();
          _afterScalar = true;
          i++;
          continue;
        case _comma:
          if (_flowKeys.isNotEmpty) _flowKeys[_flowKeys.length - 1] = true;
          _afterScalar = false;
          _flowEnd = -1;
          i++;
          continue;
        case _quote || _apostrophe:
          final close = _closeQuote(i + 1, end, unit);
          if (close < 0) {
            _open = _Open.quote;
            _openQuote = unit;
            return;
          }
          i = _afterQuoted(i, close, start, end);
          continue;
        case _colon
            when _flow > 0 && (_afterScalar || !_plainSafeAt(i + 1, end)):
          if (_flowEnd >= 0) throw _Breach(_flowEnd, yamlKeyMessage);
          if (_flowKeys.isNotEmpty) _flowKeys[_flowKeys.length - 1] = false;
          _afterScalar = false;
          i++;
          continue;
        case _dash when _flow > 0 && !_plainSafeAt(i + 1, end):
        case _bar || _gt || _amp || _star || _bang || _percent || _at || _grave:
          _lock(i, start, end);
          return;
      }
      if (!_standardAt(i, end)) {
        _lock(i, start, end);
        return;
      }
      i = _plain(i, start, end);
      if (i < 0) return;
    }
  }

  /// After a quoted scalar from [open] to [close]: in block context a `:`
  /// with a blank or the line's end after it makes it a simple key.
  int _afterQuoted(int open, int close, int start, int end) {
    _afterScalar = true;
    _flowEnd = -1;
    if (_flow > 0) return close;
    var i = close;
    while (i < end && _blank(_text.codeUnitAt(i))) {
      i++;
    }
    if (i < end && _text.codeUnitAt(i) == _colon && _blankOrEnd(i + 1, end)) {
      _key(open - start, open);
      _afterScalar = false;
      return i + 1;
    }
    return close;
  }

  /// A plain scalar from [from], one line of package:yaml's
  /// `_scanPlainScalar`: returns where the next token starts, past a `:`
  /// that makes it a simple key, or -1 when the line is done.
  int _plain(int from, int start, int end) {
    final stop = _plainEnd(from, end);
    _afterScalar = false;
    _flowEnd = -1;
    if (stop < 0) {
      _open = _Open.plain;
      _plainMin = (_columns.isEmpty ? -1 : _columns.last) + 1;
      return -1;
    }
    if (stop == from) {
      _lock(from, start, end);
      return -1;
    }
    if (_flow == 0) {
      var i = stop;
      while (i < end && _blank(_text.codeUnitAt(i))) {
        i++;
      }
      if (i < end && _text.codeUnitAt(i) == _colon && _blankOrEnd(i + 1, end)) {
        _key(from - start, from);
        return i + 1;
      }
    }
    return stop;
  }

  /// The rest of a plain scalar the line before left open, from [first];
  /// in block context a `:` that ends it opens a level at the `:`, as
  /// package:yaml's `_fetchValue` rolls the indent after a plain scalar
  /// over lines.
  void _continuePlain(int first, int start, int end) {
    final stop = _plainEnd(first, end);
    if (stop < 0) {
      _open = _Open.plain;
      return;
    }
    if (stop == first) {
      _lock(first, start, end);
      return;
    }
    var i = stop;
    while (i < end && _blank(_text.codeUnitAt(i))) {
      i++;
    }
    if (_flow == 0 &&
        i < end &&
        _text.codeUnitAt(i) == _colon &&
        _blankOrEnd(i + 1, end)) {
      _key(i - start, i);
      i++;
    }
    _tokens(i, start, end);
  }

  /// Where a plain scalar from [from] ends on this line: the first
  /// character that is no plain character, or the blanks before a comment
  /// or one; -1 when it reaches the line's end, so it may go on.
  int _plainEnd(int from, int end) {
    var j = from;
    while (j < end) {
      final unit = _text.codeUnitAt(j);
      if (_blank(unit)) {
        var k = j;
        while (k < end && _blank(_text.codeUnitAt(k))) {
          k++;
        }
        if (k >= end) return -1;
        if (_text.codeUnitAt(k) == _hash || !_plainCharAt(k, end)) return j;
        j = k;
        continue;
      }
      if (!_plainCharAt(j, end)) return j;
      j += _surrogatePairAt(j, end) ? 2 : 1;
    }
    return -1;
  }

  /// A block scalar header at [at]; opens the scalar, or locks when the
  /// header is not one package:yaml reads or the scalar has no parent.
  void _blockScalarHeader(int at, int start, int end) {
    bool digit(int k) {
      if (k >= end) return false;
      final unit = _text.codeUnitAt(k);
      return unit >= 0x31 && unit <= 0x39;
    }

    bool chomping(int k) =>
        k < end &&
        (_text.codeUnitAt(k) == _plus || _text.codeUnitAt(k) == _dash);

    var j = at + 1;
    var increment = 0;
    if (chomping(j)) {
      j++;
      if (digit(j)) increment = _text.codeUnitAt(j++) - 0x30;
    } else if (digit(j)) {
      increment = _text.codeUnitAt(j++) - 0x30;
      if (chomping(j)) j++;
    }
    while (j < end && _blank(_text.codeUnitAt(j))) {
      j++;
    }
    final parent = _columns.isEmpty ? -1 : _columns.last;
    if ((j < end && _text.codeUnitAt(j) != _hash) || parent < 0) {
      _lock(at, start, end);
      return;
    }
    _open = _Open.blockScalar;
    _scalarParent = parent;
    _scalarIndent = increment == 0 ? 0 : parent + increment;
    _scalarMax = 0;
    _afterScalar = false;
  }

  /// Whether the line from [start] to [end] belongs to the open block
  /// scalar, as package:yaml's `_scanBlockScalarBreaks` and its content
  /// loop decide.
  bool _inBlockScalar(int start, int end) {
    var column = 0;
    while (start + column < end &&
        _text.codeUnitAt(start + column) == _space &&
        (_scalarIndent == 0 || column < _scalarIndent)) {
      column++;
    }
    if (_scalarIndent == 0) {
      if (column > _scalarMax) _scalarMax = column;
      if (start + column >= end) return true;
      final floor = _scalarParent + 1;
      _scalarIndent = _scalarMax > floor ? _scalarMax : floor;
    } else if (start + column >= end) {
      return true;
    }
    return column >= _scalarIndent;
  }

  /// The index after the quote that closes a quoted scalar from [from] on
  /// this line, or -1 when it does not close here.
  int _closeQuote(int from, int end, int quote) {
    for (var j = from; j < end; j++) {
      final unit = _text.codeUnitAt(j);
      if (quote == _apostrophe) {
        if (unit != _apostrophe) continue;
        if (j + 1 < end && _text.codeUnitAt(j + 1) == _apostrophe) {
          j++;
          continue;
        }
        return j + 1;
      }
      if (unit == _backslash) {
        j++;
      } else if (unit == _quote) {
        return j + 1;
      }
    }
    return -1;
  }

  void _entry(int column, int index) {
    if (_columns.isEmpty || column > _columns.last) {
      _push(column, index, mapping: false);
    } else if (column == _columns.last && _mappings.last && !_indentless.last) {
      _indentless[_indentless.length - 1] = true;
      _indentlessCount++;
      _check(index);
    }
  }

  void _key(int column, int index) {
    if (_columns.isEmpty || column > _columns.last) {
      _push(column, index, mapping: true);
    } else if (column == _columns.last && _indentless.last) {
      _indentless[_indentless.length - 1] = false;
      _indentlessCount--;
    }
  }

  void _push(int column, int index, {required bool mapping}) {
    _columns.add(column);
    _mappings.add(mapping);
    _indentless.add(false);
    _check(index);
  }

  void _pop() {
    if (_indentless.removeLast()) _indentlessCount--;
    _columns.removeLast();
    _mappings.removeLast();
  }

  void _check(int index) {
    if (_depth > yamlMaxDepth) throw _Breach(index, yamlDepthMessage);
  }

  // MARK: - The lock

  void _lock(int from, int start, int end) {
    _locked = true;
    _lockedLine(start, end, from);
  }

  /// A line, from [from], after the lock: one level for the line's first
  /// token when [from] is the line's start, and one for each `- `, `? `,
  /// `: `, `[`, and `{` outside the comment [_commentAt] proves. The
  /// collection-key rule still refuses, its context unknown: a `?` at a
  /// token start that may read as a key, at the `?`; a `:` after a `]` or
  /// `}` with only blanks, comments, and line breaks between, at that `]`
  /// or `}`; and a `[` or `{` whose last significant character is `{` or
  /// `,`, at that `[` or `{`, since the locked model no longer tracks
  /// which open collection is a mapping and errs toward refusing (design
  /// G9, G4).
  void _lockedLine(int start, int end, int from) {
    final stop = _commentAt(start, end);
    var i = from;
    if (from == start) {
      while (i < stop && _blank(_text.codeUnitAt(i))) {
        i++;
      }
      if (i >= stop) return;
      _lockedCount++;
      _check(i);
    }
    for (; i < stop; i++) {
      final unit = _text.codeUnitAt(i);
      if (_blank(unit)) continue;
      if (unit == _colon && _lockedClose >= 0) {
        throw _Breach(_lockedClose, yamlKeyMessage);
      }
      _lockedClose = unit == _closeSquare || unit == _closeCurly ? i : -1;
      if (unit == _question &&
          (i == start || _endsToken(_text.codeUnitAt(i - 1))) &&
          _keyIndicatorAt(i, end)) {
        throw _Breach(i, yamlKeyMessage);
      }
      if ((unit == _openSquare || unit == _openCurly) &&
          (_lockedLast == _openCurly || _lockedLast == _comma)) {
        throw _Breach(i, yamlKeyMessage);
      }
      final opens =
          unit == _openSquare ||
          unit == _openCurly ||
          ((unit == _dash || unit == _question || unit == _colon) &&
              _blankOrEnd(i + 1, stop));
      if (opens) {
        _lockedCount++;
        _check(i);
      }
      _lockedLast = unit;
    }
  }

  // MARK: - Characters

  bool _documentMarker(int at, int end) {
    if (at + 3 > end) return false;
    final unit = _text.codeUnitAt(at);
    if (unit != _dash && unit != _dot) return false;
    if (_text.codeUnitAt(at + 1) != unit || _text.codeUnitAt(at + 2) != unit) {
      return false;
    }
    return at + 3 == end || _blank(_text.codeUnitAt(at + 3));
  }

  /// Whether a `?` at [at] may read as an explicit key in block or flow
  /// context: no character plain-safe in both follows it.
  bool _keyIndicatorAt(int at, int end) {
    final next = at + 1;
    if (next >= end) return true;
    final unit = _text.codeUnitAt(next);
    return unit == _comma ||
        unit == _openSquare ||
        unit == _closeSquare ||
        unit == _openCurly ||
        unit == _closeCurly ||
        !_plainSafeAt(next, end);
  }

  bool _plainCharAt(int j, int end) {
    final unit = _text.codeUnitAt(j);
    if (unit == _colon) return _plainSafeAt(j + 1, end);
    if (unit == _hash) return j > 0 && !_blank(_text.codeUnitAt(j - 1));
    return _plainSafeAt(j, end);
  }

  bool _plainSafeAt(int j, int end) {
    if (j >= end) return false;
    final unit = _text.codeUnitAt(j);
    if (unit == _comma ||
        unit == _openSquare ||
        unit == _closeSquare ||
        unit == _openCurly ||
        unit == _closeCurly) {
      return _flow == 0;
    }
    if (_blank(unit) || unit == _bom) return false;
    if (unit == _nel) return true;
    return _standardAt(j, end);
  }

  bool _standardAt(int j, int end) {
    final unit = _text.codeUnitAt(j);
    if (unit >= 0xD800 && unit <= 0xDBFF) return _surrogatePairAt(j, end);
    return (unit >= _space && unit <= 0x7E) ||
        (unit >= 0xA0 && unit <= 0xD7FF) ||
        (unit >= 0xE000 && unit <= 0xFFFD);
  }

  bool _surrogatePairAt(int j, int end) {
    final unit = _text.codeUnitAt(j);
    if (unit < 0xD800 || unit > 0xDBFF || j + 1 >= end) return false;
    final next = _text.codeUnitAt(j + 1);
    return next >= 0xDC00 && next <= 0xDFFF;
  }

  bool _blankOrEnd(int j, int end) => j >= end || _blank(_text.codeUnitAt(j));

  static bool _blank(int unit) => unit == _space || unit == _tab;
}
