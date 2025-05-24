// lib/src/reader/lexer.dart

import 'token.dart';

const EOF = '\x00'; // ソースコードの終端を示す特殊文字

class Lexer {
  final String _source;
  final List<Token> _tokens = [];
  int _start = 0; // 現在のスキャン中の字句の開始位置
  int _current = 0; // 現在見ている文字の位置
  int _line = 1; // 現在の行番号
  int _column = 1; // 現在の列番号

  // TODO: エラー報告用のリストやコールバック
  // final List<LexerError> _errors = [];

  /// Lexerオブジェクトのコンストラクタ
  Lexer(this._source);

  /// ソースコードの終端までトークンをスキャンする
  List<Token> scanTokens() {
    while (!_isAtEnd()) {
      _start = _current;
      _scanToken();
    }
    _tokens.add(Token(TokenType.eof, "", null, _line, _column));
    return _tokens;
  }

  /// ソースコードの終端に達したかどうかをチェック
  bool _isAtEnd() => _current >= _source.length;

  /// 現在の文字を進めて返す(消費する)
  String _advance() {
    final char = _source[_current++];
    if (char == '\n') {
      _line++;
      _column = 1; // 改行で列をリセット
    } else {
      _column++; // 列を進める
    }
    return char;
  }

  /// トークン追加のヘルパー数
  void _addToken(TokenType type, [Object? literal]) {
    final lexeme = _source.substring(_start, _current);
    _tokens.add(Token(type, lexeme, literal, _line, _column - lexeme.length));
  }

  /// 1文字先読み: 文字を確認するが、現在の位置は変えない(消費しない)
  String _peek() => _isAtEnd() ? EOF : _source[_current];

  /// 2文字先読み: 文字を確認するが、現在の位置は変えない(消費しない)
  String _peekNext() => (_current + 1 >= _source.length) ? EOF : _source[_current + 1];

  /// 次の文字が期待する文字であればそれを消費してtrueを返す
  /// そうでなければ消費せずにfalseを返す
  bool _match(String expected) {
    if (_isAtEnd() || _source[_current] != expected) return false;
    _advance(); // 期待する文字を消費
    return true;
  }

  // 0-9かどうかを
  bool _isDigit(String c) => c.compareTo('0') >= 0 && c.compareTo('9') <= 0;

  bool _isHexDigit(String c) {
    return _isDigit(c) ||
        (c.compareTo('a') >= 0 && c.compareTo('f') <= 0) ||
        (c.compareTo('A') >= 0 && c.compareTo('F') <= 0);
  }

  bool _isOctalDigit(String c) {
    return c.compareTo('0') >= 0 && c.compareTo('7') <= 0;
  }

  bool _isAlpha(String c) {
    return (c.compareTo('a') >= 0 && c.compareTo('z') <= 0) ||
        (c.compareTo('A') >= 0 && c.compareTo('Z') <= 0) ||
        c == '_'; // アンダースコアは識別子の一部として許可
  }

  // トークン判別ロジック
  void _scanToken() {
    String c = _advance();
    switch (c) {
      case '(':
        _addToken(TokenType.leftParen);
      case ')':
        _addToken(TokenType.rightParen);
      case '[':
        _addToken(TokenType.leftBracket);
      case ']':
        _addToken(TokenType.rightBracket);
      case '{':
        _addToken(TokenType.leftBrace);
      case '}':
        _addToken(TokenType.rightBrace);
      case '\'':
        _addToken(TokenType.quote);
      case '`':
        _addToken(TokenType.syntaxQuote);
      case '@':
        _addToken(TokenType.deref);
      case '~':
        if (_match('@')) {
          _addToken(TokenType.unquoteSplicing);
        } else {
          _addToken(TokenType.unquote);
        }
      case '#':
        // Clojureのディスパッチマクロは多様
        // #_ (ignore next form)
        // #{ (set)
        // #" (regex)
        // #' (var)
        // #( (fn literal)
        // etc.
        // ここでは TokenType.dispatch として登録し、パーサーで詳細を判断
        // もしくは、ここで一部を判別しても良い (例: #_ はコメント扱いもできる)
        // 今回のTokenType.commentは ; comment なので、#はdispatchが適切
        _addToken(TokenType.dispatch);
      case ';':
        // コメントはトークンとして追加しない
        while (_peek() != '\n' && !_isAtEnd()) {
          _advance();
        }
        _addToken(TokenType.comment); // TODO: 将来デバッガ用に使うかも
      case ' ':
      case '\r':
      case '\t':
      case ',':
        // 空白文字はスキップ(カンマも空白文字として扱う)
        break;
      case '"':
        _string();
      case ':':
        _keyword();
      case '\\':
        _character();
      default:
        if (_isDigit(c)) {
          _number();
        } else if (_isAlphaOrSymbolStart(c)) {
          _identifier();
        } else {
          // エラー処理: 予期しない文字を報告
          print('Error: Unexpected character "$c" at $_line:${_column - 1}');
        }
    }
  }
}
