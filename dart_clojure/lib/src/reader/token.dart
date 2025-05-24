// lib/src/reader/token.dart

// Tokenizer for Dart Clojure

enum TokenType {
  leftParen,
  rightParen,
  leftBracket,
  rightBracket,
  leftBrace,
  rightBrace,
  string,
  number,
  character,
  boolean,
  nil,
  symbol,
  keyword,
  quote,
  deref, // リーダーマクロ
  dispatch, // #{}(セット), #"regex", #'var, #()匿名関数, #_無視
  syntaxQuote,
  unquote,
  unquoteSplicing,
  comment,
  eof,
}

class Token {
  final TokenType type;
  final String lexeme; // トークンの生テキスト
  final Object? literal; // リテラルの実際の値 (例: int, String)
  final int line;
  final int column;

  Token(this.type, this.lexeme, this.literal, this.line, this.column);

  @override
  String toString() => 'Token(${type.name}, "$lexeme", $literal, Ln $line, Col $column)';
}

// lib/src/reader/tokenizer.dart
class Tokenizer {
  final String source;
  final List<Token> _tokens = [];
  int _start = 0;
  int _current = 0;
  int _line = 1;
  int _lineStart = 0; // 列計算用

  Tokenizer(this.source);

  List<Token> scanTokens() {
    while (!_isAtEnd()) {
      _start = _current;
      _scanToken();
    }
    _tokens.add(Token(TokenType.eof, "", null, _line, _current - _lineStart + 1));
    return _tokens;
  }

  bool _isAtEnd() => _current >= source.length;

  void _scanToken() {
    final char = _advance();
    switch (char) {
      case '(':
        _addToken(TokenType.leftParen);
        break;
      case ')':
        _addToken(TokenType.rightParen);
        break;
      case '':
        _addToken(TokenType.rightBracket);
        break;
      case '{':
        _addToken(TokenType.leftBrace);
        break;
      case '}':
        _addToken(TokenType.rightBrace);
        break;
      case "'":
        _addToken(TokenType.quote);
        break;
      case '@':
        _addToken(TokenType.deref);
        break;
      case '`':
        _addToken(TokenType.syntaxQuote);
        break;
      case '~':
        if (_match('@')) {
          _addToken(TokenType.unquoteSplicing);
        } else {
          _addToken(TokenType.unquote);
        }
        break;
      case '#':
        // セット #{}, 正規表現 #"pattern", var #', fn #(), 無視 #_ など
        // ディスパッチマクロにはより高度な先読みまたはサブパーサーが必要
        _addToken(TokenType.dispatch); // 現時点では簡略化
        break;
      case ';': // コメント
        while (_peek() != '\n' && !_isAtEnd()) {
          _advance();
        }
        // コメントトークンは追加せず、消費するだけ
        break;
      case '"':
        _string();
        break;
      case ' ':
      case '\r':
      case '\t':
        // 空白は無視
        break;
      case '\n':
        _line++;
        _lineStart = _current;
        break;
      default:
        if (_isDigit(char)) {
          _number();
        } else if (_isAlphaNumeric(char) || _isSymbolSpecialChar(char)) {
          _identifierOrSymbol();
        } else if (char == ':') {
          _keyword();
        } else if (char == '\\') {
          _character();
        } else {
          // エラー処理: 予期しない文字を報告
          print(
            "Error: Unexpected character '$char' at line $_line, column ${_current - _lineStart}",
          );
        }
    }
  }

  String _advance() => source[_current++];
  void _addToken(TokenType type, [Object? literal]) {
    final text = source.substring(_start, _current);
    _tokens.add(Token(type, text, literal, _line, _start - _lineStart + 1));
  }

  bool _match(String expected) {
    if (_isAtEnd()) return false;
    if (source[_current] != expected) return false;
    _current++;
    return true;
  }

  String _peek() => _isAtEnd() ? '\x00' : source[_current];
  String _peekNext() => (_current + 1 >= source.length) ? '\x00' : source[_current + 1];

  void _string() {
    while (_peek() != '"' && !_isAtEnd()) {
      if (_peek() == '\n') {
        _line++;
        _lineStart = _current + 1; // \n を進めた後
      }
      // \n, \t, \\, \" のようなエスケープシーケンスを処理
      if (_peek() == '\\' && !_isAtEndNext()) {
        _advance(); // '\' を消費
      }
      _advance();
    }
    if (_isAtEnd()) {
      print("Error: Unterminated string at line $_line.");
      return;
    }
    _advance(); // 閉じる ".
    final value = source.substring(_start + 1, _current - 1);
    // TODO: 'value' 内のエスケープシーケンスを処理
    _addToken(TokenType.string, value);
  }

  bool _isDigit(String char) => char.compareTo('0') >= 0 && char.compareTo('9') <= 0;

  void _number() {
    // 整数、浮動小数点数、比率 (N/M)、BigInt (N)、16進数 (0x)、8進数 (0)、基数 (2r) を処理
    // これは整数と基本的な浮動小数点数の簡略版
    while (_isDigit(_peek())) {
      _advance();
    }
    if (_peek() == '.' && _isDigit(_peekNext())) {
      _advance(); // "." を消費
      while (_isDigit(_peek())) {
        _advance();
      }
      _addToken(TokenType.number, double.parse(source.substring(_start, _current)));
    } else if (_peek() == 'N' && (_isAtEndNext() || !_isAlphaNumeric(_peekNext()))) {
      // BigInt
      _advance(); // N を消費
      _addToken(TokenType.number, BigInt.parse(source.substring(_start, _current - 1)));
    }
    // 比率、16進数などの数値解析ロジックをここに追加 [8, 9]
    else {
      final numString = source.substring(_start, _current);
      final intVal = int.tryParse(numString);
      if (intVal != null) {
        _addToken(TokenType.number, intVal);
      } else {
        final bigIntVal = BigInt.tryParse(numString);
        if (bigIntVal != null) {
          _addToken(TokenType.number, bigIntVal);
        } else {
          print("Error: Invalid number format '$numString' at line $_line.");
        }
      }
    }
  }

  bool _isAlpha(String char) {
    final c = char.codeUnitAt(0);
    return (c >= 'a'.codeUnitAt(0) && c <= 'z'.codeUnitAt(0)) ||
        (c >= 'A'.codeUnitAt(0) && c <= 'Z'.codeUnitAt(0)) ||
        c == '_'.codeUnitAt(0);
  }

  bool _isAlphaNumeric(String char) => _isAlpha(char) || _isDigit(char);
  bool _isSymbolSpecialChar(String char) {
    // Clojure シンボルは *, +,!, -, _, ',?, <, >, = を含むことができる
    // / と. は特別な意味を持つ (名前空間, クラス)
    return ['*', '+', '!', '-', '_', "'", '?', '<', '>', '=', '.', '/'].contains(char);
  }

  bool _isAtEndNext() => _current + 1 >= source.length;

  void _identifierOrSymbol() {
    // シンボル, nil, true, false を処理
    while (_isAlphaNumeric(_peek()) || _isSymbolSpecialChar(_peek())) {
      _advance();
    }
    final text = source.substring(_start, _current);
    if (text == "nil") {
      _addToken(TokenType.nil, null); // Clojure nil
    } else if (text == "true") {
      _addToken(TokenType.boolean, true);
    } else if (text == "false") {
      _addToken(TokenType.boolean, false);
    } else {
      // 名前空間付きシンボル (例: my-ns/foo) や Java クラス名 (例: java.util.Date) をさらにチェック
      // 現時点ではすべて単純なシンボルとして扱う
      _addToken(TokenType.symbol, DartjureSymbol(text)); // カスタム Symbol クラスを使用
    }
  }

  void _keyword() {
    // キーワードは : または :: で始まる
    // 例: :foo, :my.ns/bar, ::baz, ::another-ns/qux
    bool doubleColon = _match(':'); // 自動解決キーワードのための2番目のコロンをチェック

    while (_isAlphaNumeric(_peek()) || _isSymbolSpecialChar(_peek()) || _peek() == '/') {
      _advance();
    }
    final text = source.substring(_start, _current);
    _addToken(TokenType.keyword, DartjureKeyword(text, isDoubleColon: doubleColon));
  }

  void _character() {
    // \c, \newline, \space, \tab, \uXXXX, \oNNN [8]
    if (_isAtEnd()) {
      print("Error: Unterminated character literal at line $_line.");
      return;
    }
    // 簡単なケース: \c
    // より複雑なケース: \newline, \u0041 など
    String charLiteral;
    if (_current + "newline".length <= source.length &&
        source.substring(_current, _current + "newline".length) == "newline") {
      _current += "newline".length;
      charLiteral = "\n";
    } else if (_current + "space".length <= source.length &&
        source.substring(_current, _current + "space".length) == "space") {
      _current += "space".length;
      charLiteral = " ";
    } else if (_current + "tab".length <= source.length &&
        source.substring(_current, _current + "tab".length) == "tab") {
      _current += "tab".length;
      charLiteral = "\t";
    }
    // \uXXXX と \oNNN の解析を追加
    else {
      if (!_isAtEnd()) {
        charLiteral = source[_current];
        _advance();
      } else {
        print("Error: Incomplete character literal at line $_line.");
        return;
      }
    }
    _addToken(TokenType.character, charLiteral);
  }
}
