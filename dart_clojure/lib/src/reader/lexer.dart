// lib/src/reader/lexer.dart

import 'dart:math' as math;
import 'token.dart';

const preferInline = pragma("vm:prefer-inline");
const EOF = '\x00'; // ソースコードの終端を示す特殊文字 (内部でのみ使用)
const ZERO = 48;
const ONE = 49;
const SEVEN = 55;
const NINE = 57;
const A_UP = 65;
const F_UP = 70;
const Z_UP = 90;
const A_LOW = 97;
const F_LOW = 102;
const Z_LOW = 122;

class Lexer {
  final String _source;
  final List<Token> _tokens = [];
  int _start = 0; // 現在のスキャン中の字句の開始位置
  int _current = 0; // 現在見ている文字の位置
  int _line = 1; // 現在の行番号
  int _column = 1; // 現在の列番号 (次の文字の列)

  // トークン開始位置の保存用
  int _tokenStartLine = 1;
  int _tokenStartColumn = 1;

  // TODO: エラー報告用のリストやコールバック
  // final List<LexerError> _errors = [];

  static final Map<String, TokenType> _reservedWords = {
    'nil': TokenType.nil,
    'true': TokenType.boolean,
    'false': TokenType.boolean,
  };

  /// Lexerオブジェクトのコンストラクタ
  Lexer(this._source);

  /// ソースコードの終端までトークンをスキャンする
  List<Token> scanTokens() {
    while (!_isAtEnd()) {
      _start = _current;
      _tokenStartLine = _line;
      _tokenStartColumn = _column;
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

  /// トークン追加のヘルパー
  void _addToken(TokenType type, [Object? literal]) {
    final lexeme = _source.substring(_start, _current);
    _tokens.add(Token(type, lexeme, literal, _tokenStartLine, _tokenStartColumn));
  }

  /// 1文字先読み: 文字を確認するが、現在の位置は変えない(消費しない)
  String _peek() => _isAtEnd() ? EOF : _source[_current];

  /// 2文字先読み: 文字を確認するが、現在の位置は変えない(消費しない)
  String _peekNext() => (_current + 1 >= _source.length) ? EOF : _source[_current + 1];

  /// 次の文字が期待する文字であればそれを消費してtrueを返す
  /// そうでなければ消費せずにfalseを返す
  bool _match(String expected) {
    if (_isAtEnd() || _source[_current] != expected) return false;
    // _advance() を呼ぶと _line, _column が更新されてしまうので、
    // マッチした文字を消費するだけなら _current を進めるだけで良い場合もある。
    // ここでは _advance() を使うことで line/column 更新を一貫させる。
    _advance();
    return true;
  }

  // inline推奨
  @preferInline
  bool _between(String str, int start, int end) {
    if (str.isEmpty) return false; // 空文字チェック
    final code = str.codeUnitAt(0);
    return code >= start && code <= end;
  }

  bool _isDigit(String c) => c != EOF && _between(c, ZERO, NINE);
  bool _isOctalDigit(String c) => c != EOF && _between(c, ZERO, SEVEN);
  bool _isHexDigit(String c) =>
      c != EOF && (_isDigit(c) || _between(c, A_LOW, F_LOW) || _between(c, A_UP, F_UP));

  bool _isAlpha(String c) {
    if (c == EOF || c.isEmpty) return false;
    final code = c.codeUnitAt(0);
    return (code >= A_LOW && code <= Z_LOW) || (code >= A_UP && code <= Z_UP);
  }

  bool _isAlphaNumeric(String c) => _isDigit(c) || _isAlpha(c);

  // Clojureのシンボル文字判定 (Clojure Spec準拠)
  // https://clojure.org/reference/reader#_symbols
  bool _isClojureSymbolChar(String char, bool isStartChar) {
    if (char == EOF || char.isEmpty) return false;

    const nonSymbolChars = '[]{}"()\\;~@`^%'; // # と , は別途処理
    if (nonSymbolChars.contains(char)) return false;
    if (char.trim().isEmpty || char == ',') return false; // Whitespace and comma

    if (isStartChar) {
      if (_isDigit(char)) return false;
      if (char == ':') return false; // Keywords start with :
      if (char == '#')
        return false; // Dispatch chars (except ##Inf etc handled in _number)
    }
    // '/', '.', '+', '-', '*' etc. are allowed.
    return true;
  }

  bool _isClojureSymbolStartChar(String char) => _isClojureSymbolChar(char, true);

  void _scanToken() {
    String c = _advance();
    switch (c) {
      case '(':
        _addToken(TokenType.leftParen);
        break;
      case ')':
        _addToken(TokenType.rightParen);
        break;
      case '[':
        _addToken(TokenType.leftBracket);
        break;
      case ']':
        _addToken(TokenType.rightBracket);
        break;
      case '{':
        _addToken(TokenType.leftBrace);
        break;
      case '}':
        _addToken(TokenType.rightBrace);
        break;
      case '\'':
        _addToken(TokenType.quote);
        break;
      case '`':
        _addToken(TokenType.syntaxQuote);
        break;
      case '@':
        _addToken(TokenType.deref);
        break;
      case '~':
        if (_match('@')) {
          _addToken(TokenType.unquoteSplicing);
        } else {
          _addToken(TokenType.unquote);
        }
        break;
      case ';': // コメント
        while (_peek() != '\n' && !_isAtEnd()) {
          _advance();
        }
        _addToken(TokenType.comment); // デバッガ用にコメントもトークン化するオプション
        break;
      case '"': // 文字列
        _string();
        break;
      case ':': // キーワード
        _keyword();
        break;
      case '\\': // 文字リテラル
        _character();
        break;
      case '#': // ディスパッチマクロ
        _dispatch();
        break;
      // 空白文字とカンマ (Clojureではカンマは空白扱い)
      case ' ':
      case '\r':
      case '\t':
      case '\n': // _advance で処理済みだが、明示的にスキップ
      case ',':
        break; // スキップ

      default:
        // 数値の可能性チェック: 数字で始まるか、[+-]の後に数字が続く場合
        if (_isDigit(c) || ((c == '+' || c == '-') && _isDigit(_peek()))) {
          _number(c); // cは既に消費された最初の文字
        } else if (_isClojureSymbolStartChar(c)) {
          // シンボルの開始文字か
          _symbol(c); // cは既に消費された最初の文字
        } else {
          // 不明な文字: エラーとして処理するか、単に無視するか
          // print("Unexpected character: $c at Ln $_line Col $_column");
          // ここでは不明な文字もシンボルとして扱ってみる (Clojureの寛容性に合わせて)
          // ただし、isClojureSymbolStartCharでfalseになるものは問題
          // より厳密にはエラーとすべき
          if (!c.trim().isEmpty) {
            // EOFやその他の内部処理文字でない限り
            // エラーとして不明なトークンを追加することもできる
            // _tokens.add(Token(TokenType.error, c, "Unexpected character", _tokenStartLine, _tokenStartColumn));
          }
        }
        break;
    }
  }

  void _string() {
    // _startは '"' の位置、_current は '"' の次の位置
    final buffer = StringBuffer();
    while (_peek() != '"' && !_isAtEnd()) {
      String char = _peek();
      if (char == '\\') {
        _advance(); // '\'を消費
        if (_isAtEnd()) {
          /* エラー: 未終端エスケープ */
          buffer.write('\\');
          break;
        }
        String nextChar = _advance(); // エスケープされる文字を消費
        switch (nextChar) {
          case 't':
            buffer.write('\t');
            break;
          case 'b':
            buffer.write('\b');
            break;
          case 'n':
            buffer.write('\n');
            break;
          case 'r':
            buffer.write('\r');
            break;
          case 'f':
            buffer.write('\f');
            break;
          case '\'':
            buffer.write('\'');
            break;
          case '"':
            buffer.write('"');
            break;
          case '\\':
            buffer.write('\\');
            break;
          case 'u': // Unicode \uXXXX
            String unicodeSequence = "";
            for (int i = 0; i < 4; ++i) {
              if (_isAtEnd() || !_isHexDigit(_peek())) {
                /* エラー: 不正なUnicodeエスケープ */
                unicodeSequence = "";
                break;
              }
              unicodeSequence += _advance();
            }
            if (unicodeSequence.length == 4) {
              try {
                buffer.writeCharCode(int.parse(unicodeSequence, radix: 16));
              } catch (e) {
                /* エラー */
                buffer.write('\\u$unicodeSequence');
              } // パース失敗時はそのまま追加
            } else {
              buffer.write('\\u$unicodeSequence'); // 不完全な場合
            }
            break;
          default: // Octal \OOO (O is 0-7) or invalid escape
            if (_isOctalDigit(nextChar)) {
              String octalSeq = nextChar;
              // 最大2文字まで追加で読む (計3桁)
              for (int i = 0; i < 2 && _isOctalDigit(_peek()); ++i) {
                octalSeq += _advance();
              }
              try {
                buffer.writeCharCode(int.parse(octalSeq, radix: 8));
              } catch (e) {
                /* エラー */
                buffer.write('\\$octalSeq');
              }
            } else {
              // 不正なエスケープシーケンスはそのままバックスラッシュと文字を追加
              buffer.write('\\');
              buffer.write(nextChar);
            }
            break;
        }
      } else {
        buffer.write(_advance()); // 通常の文字を消費して追加
      }
    }

    if (_isAtEnd()) {
      // 未終端文字列エラー
      // _addToken(TokenType.error, "Unterminated string."); // 将来的なエラー処理
      _addToken(TokenType.string, buffer.toString()); // 現状では、そこまでの文字列をトークン化
      return;
    }

    _advance(); // 閉じる '"' を消費
    _addToken(TokenType.string, buffer.toString());
  }

  void _character() {
    // _startは '\' の位置、_current は '\' の次の位置
    Object? literal;
    if (_isAtEnd()) {
      // '\' の直後にEOF
      _addToken(TokenType.symbol, '\\'); // '\'単体をシンボルとして扱う (Clojureの挙動)
      return;
    }

    // \u, \o のケースを先に処理
    if (_peek() == 'u') {
      _advance(); // 'u' を消費
      String hexValue = "";
      for (int i = 0; i < 4; i++) {
        if (_isHexDigit(_peek())) {
          hexValue += _advance();
        } else {
          hexValue = "";
          break; /* 不正なUnicode */
        }
      }
      if (hexValue.length == 4) {
        try {
          literal = String.fromCharCode(int.parse(hexValue, radix: 16));
        } catch (_) {}
      }
    } else if (_peek() == 'o') {
      _advance(); // 'o' を消費
      String octalValue = "";
      for (int i = 0; i < 3 && _isOctalDigit(_peek()); i++) {
        octalValue += _advance();
      }
      if (octalValue.isNotEmpty) {
        try {
          literal = String.fromCharCode(int.parse(octalValue, radix: 8));
        } catch (_) {}
      } else {
        /* \o の後に数字がない場合は 'o' 自身として扱うかエラー。ここでは 'o' ではない。 */
      }
    } else {
      // 名前付き文字か、単一文字
      String nameOrChar = "";
      // 英字が続く限り読む (Clojureのnamed charは英字のみ)
      while (_isAlpha(_peek())) {
        nameOrChar += _advance();
      }

      if (nameOrChar.isNotEmpty) {
        switch (nameOrChar) {
          case "newline":
            literal = '\n';
            break;
          case "space":
            literal = ' ';
            break;
          case "tab":
            literal = '\t';
            break;
          case "formfeed":
            literal = '\f';
            break;
          case "backspace":
            literal = '\b';
            break;
          case "return":
            literal = '\r';
            break;
          default: // 知らない名前なら、最初の1文字がリテラルで、残りは次のトークン
            _current = _start + 1 + 1; // '\' + 最初の1文字 の後
            // _column の調整 (_startからの差分で再計算が安全)
            // 簡単のため、ここでは _column の精密な巻き戻しは省略。
            // _tokenStartColumn からのオフセットで計算すべき。
            // とりあえず、 _column -= (nameOrChar.length -1); (近似)
            // 実際には _column は _advance() で更新されるので、_current の操作が主。
            _column = _tokenStartColumn + 1 + 1; // '\' と 1文字分
            literal = nameOrChar[0];
            break;
        }
      } else {
        // 英字が続かなかった場合 (例: '\%', '\1')
        if (!_isAtEnd()) {
          // '\'の後に何か文字がある
          literal = _advance(); // その1文字を消費
        } else {
          /* '\' で終わっている。これは _scanToken の isAtEnd で処理されるべきだが念のため */
        }
      }
    }

    if (literal != null) {
      _addToken(TokenType.character, literal);
    } else {
      // 有効な文字リテラルにならなかった場合、'\' + 消費した文字列をシンボルとして扱うなど、
      // Clojureのリーダーは寛容な場合がある。
      // ここでは、不正な文字リテラルとして、元の文字列部分を値なしでトークン化する。
      // _currentは進んでいるので、_source.substring(_start, _current) がその部分。
      _addToken(TokenType.character, null); // literalがnullならエラーを示す
    }
  }

  void _keyword() {
    // _startは ':' の位置、_current は ':' の次の位置
    bool autoResolve = false;
    if (_peek() == ':') {
      autoResolve = true;
      _advance(); // 2つ目の ':' を消費
    }

    // キーワードの名前部分 (シンボルと同様のルールだが、通常 '.' を含まない)
    // nameStartは ':' または '::' の後の位置
    while (!_isAtEnd() && _isClojureSymbolChar(_peek(), false)) {
      // Clojureキーワードは通常 '/' 以外の特殊文字をあまり使わないが、シンボル文字ルールに従う
      // ':' はキーワード名には使えない (e.g. :foo:bar は不可)
      if (_peek() == ':') break;
      _advance();
    }
    // リテラルはキーワード文字列全体（例：":foo", "::bar/baz"）
    _addToken(TokenType.keyword, _source.substring(_start, _current));
  }

  void _symbol(String firstChar) {
    // firstChar は既に消費済み。_startはその位置。_currentはその次の位置。
    // String firstChar は _source[_start] と同じ。
    while (!_isAtEnd() && _isClojureSymbolChar(_peek(), false)) {
      // シンボル内の '.' と '/' の連続や末尾のチェックはパーサーの役割。
      // Lexerは有効なシンボル構成文字のシーケンスを捉える。
      // 特殊なシンボル '.','..' や '/' もこのループで処理される。
      _advance();
    }
    final text = _source.substring(_start, _current);

    // 予約語のチェック
    if (_reservedWords.containsKey(text)) {
      final type = _reservedWords[text]!;
      if (type == TokenType.nil) {
        _addToken(type, null);
      } else if (type == TokenType.boolean) {
        _addToken(type, text == "true");
      }
    } else {
      _addToken(TokenType.symbol, text); // シンボルのリテラルはその名前
    }
  }

  void _dispatch() {
    // _startは '#' の位置、_current は '#' の次の位置
    if (_isAtEnd()) {
      // '#' で終わる場合
      _addToken(TokenType.symbol, '#'); // '#' 単体はシンボルとして扱う
      return;
    }

    switch (_peek()) {
      case '{': // #{ Set literal start
        _advance();
        _addToken(TokenType.dispatch); // Lexeme: "#{"
        break;
      case '"': // #" Regex pattern start
        _advance();
        _regexLiteral(); // Lexeme: #"pattern"
        break;
      case '\'': // #' Var quote
        _advance();
        _addToken(TokenType.dispatch); // Lexeme: "#'"
        break;
      case '(': // #() Anonymous function literal start
        _advance();
        _addToken(TokenType.dispatch); // Lexeme: "#("
        break;
      case '_': // #_ Ignore next form
        _advance();
        _addToken(TokenType.dispatch); // Lexeme: "#_"
        break;
      case '^': // #^ Metadata
        _advance();
        _addToken(TokenType.dispatch); // Lexeme: "#^"
        break;
      case ':': // #: or #:: Namespace map
        _advance(); // ':' を消費
        if (_peek() == ':') {
          // #::
          _advance(); // 2つ目の ':' を消費
        }
        _addToken(TokenType.dispatch); // Lexeme: "#:" or "#::"
        break;
      case '=': // #= Evaluate
        _advance();
        _addToken(TokenType.dispatch); // Lexeme: "#="
        break;
      case '!': // #! Shebang line or comment
        _advance();
        // ファイルの先頭なら行末までコメント扱い
        if (_start == 0 && _tokenStartLine == 1 && _tokenStartColumn == 1) {
          while (_peek() != '\n' && !_isAtEnd()) {
            _advance();
          }
          // Shebangはトークンとしては無視するか、特別なコメントトークンにすることもできる
          // ここでは _addToken でコメントとして追加しても良いし、何もしなくても良い
        } else {
          // ファイル先頭以外での #! はエラーか、特別な意味を持つ場合がある
          // ここでは dispatch トークンとしておく ("#!")
          _addToken(TokenType.dispatch);
        }
        break;
      case '?': // #? or #?@ Reader conditional
        _advance(); // '?' を消費
        if (_peek() == '@') {
          _advance(); // '@' を消費
        }
        _addToken(TokenType.dispatch); // Lexeme: "#?" or "#?@"
        break;
      case '#': // ##Inf, ##NaN, ##-Inf (数値として処理)
        // このケースは _scanToken の数値判定で処理されるべきだが、
        // '#'のdefaultで来た場合はこちらで対応。
        // _start は最初の'#'、_currentは２番目の'#'の直後。
        // _number() は最初の文字を引数に取るので、ここでは '##' を処理する。
        _advance(); // 2つ目の'#'を消費
        _number('#', isSpecialNumeric: true); // 最初の文字を'#'として渡し、特別処理フラグを立てる
        break;
      default:
        // 上記以外の #foo (タグ付きリテラルなど)
        // Lexerは '#' をdispatchトークンとし、'foo' は後続のシンボルトークンとして処理させる。
        // または、'#foo' 全体を一つのトークンとするか。
        // Clojureのリーダーマクロの動作に合わせ、'#' のみを dispatch とし、
        // 'foo' は次の _scanToken() でシンボルとして読まれるようにする。
        // ただし、TokenType.dispatchのコメントは `#{}` 等の組み合わせを示唆している。
        // ここでは、不明なディスパッチは '#' とそれに続く1文字で1つのdispatchトークンとする。
        // if (_isClojureSymbolStartChar(_peek())) {
        //   _advance(); // タグの最初の文字を消費 (ここではしない、#自体をトークンにする)
        // }
        // _addToken(TokenType.dispatch); // Lexeme: "#" (この場合)
        // 上記Enumのコメントに合わせて、# + nextCharを一つのdispatchにするなら
        if (!_isAtEnd()) _advance(); // 次の文字もlexemeに含める
        _addToken(TokenType.dispatch); // Lexeme: "#" + nextChar
        break;
    }
  }

  void _regexLiteral() {
    // _startは '#' の位置、_current は '#"' の次の位置
    // 正規表現の内容を文字列として読み込む（エスケープされた " を含む）
    final buffer = StringBuffer(); // パターン内容のみ
    while (!_isAtEnd()) {
      if (_peek() == '"') {
        _advance(); // 閉じる '"' を消費
        _addToken(TokenType.dispatch, buffer.toString()); // リテラルはパターン文字列
        return;
      }
      if (_peek() == '\\') {
        // エスケープシーケンス
        _advance(); // '\' を消費
        if (_isAtEnd()) {
          /* エラー: 未終端エスケープ */
          buffer.write('\\');
          break;
        }
        buffer.write('\\'); // バックスラッシュ自体をバッファに
        buffer.write(_advance()); // エスケープされる文字をバッファに
      } else {
        buffer.write(_advance());
      }
    }
    // 未終端正規表現エラー
    _addToken(
      TokenType.dispatch,
      buffer.toString(),
    ); // ここまでの内容でトークン化 (エラーを示すためにliteralが不完全)
  }

  void _number(String firstCharOrHash, {bool isSpecialNumeric = false}) {
    // firstCharOrHash: 既に消費された数値の最初の文字、または'#'(isSpecialNumeric=true時)
    // _startはその文字の位置、_currentはその次の位置。

    StringBuffer numBuffer = StringBuffer()..write(firstCharOrHash);
    Object? literalValue;

    if (isSpecialNumeric) {
      // ##Inf, ##NaN, ##-Inf の処理
      // この時点で numBuffer は "#" を持っている。_peek() は２つ目の'#'の次。
      // (この関数が呼ばれる前に2つ目の#も消費されている想定に修正)
      // _scanTokenからの呼び出しで'##'まで消費済みにする。
      // void _number({bool fromHash = false})
      // if (fromHash) numBuffer.write(_advance()); // consume second '#'
      // --> _dispatchの'##'ケースで'##'をnumBufferにセットしてからここに来るようにする。
      // --> または、_scanTokenで'##'を認識したら、Inf/NaNを読むロジックをここに。
      // 現在の呼び出し方: _number('#', isSpecialNumeric: true)
      // この場合、numBuffer は "#"。_peek()は2番目の'#'の文字。
      // _dispatch から呼び出す場合、_start は最初の '#'、_current は２番目の '#' の後。
      // numBufferは "##" となっているべき。
      // _numberが呼ばれる前に numBuffer = StringBuffer()..write(_source.substring(_start, _current));
      // を行うように _scanToken側を調整するか、ここで読む。

      // isSpecialNumeric が true の場合、_start は最初の'#'、_current は２番目の'#'の後ろ。
      // numBuffer を再構築。
      numBuffer.clear();
      numBuffer.write(_source.substring(_start, _current)); // "##"

      String specialPart = "";
      if (_peek() == '-') {
        // ##-Inf
        specialPart += _advance();
      }
      while (_isAlpha(_peek())) {
        specialPart += _advance();
      }
      numBuffer.write(specialPart);
      final fullSpecial = numBuffer.toString();

      if (fullSpecial == "##Inf")
        literalValue = double.infinity;
      else if (fullSpecial == "##-Inf")
        literalValue = double.negativeInfinity;
      else if (fullSpecial == "##NaN")
        literalValue = double.nan;
      else {
        /* エラー: 不明な ## シーケンス */
      }
      _addToken(TokenType.number, literalValue);
      return;
    }

    // 通常の数値処理
    // firstCharOrHash は [+-] または数字。numBuffer には既に入っている。

    // 基数 (radix) の処理: `digitsRadixRdigits` (e.g., `2r101`, `36rAZ`)
    // 最初の部分が数字で、次に 'r' か 'R' が来て、その次が英数字の場合
    bool isRadix = false;
    int radixValue = 0;
    if (_isDigit(firstCharOrHash)) {
      // 符号なしで数字から始まる場合のみ基数指定を考慮
      // ここで numBuffer には最初の数字(群)が入るように読む
      while (_isDigit(_peek())) {
        numBuffer.write(_advance());
      }
      if (_peek().toLowerCase() == 'r' && _isAlphaNumeric(_peekNext())) {
        try {
          radixValue = int.parse(numBuffer.toString());
          if (radixValue >= 2 && radixValue <= 36) {
            _advance(); // 'r' or 'R' を消費
            numBuffer.write('r'); // 'r'も字句に含める
            isRadix = true;
            // 基数部分の数字を読む
            while (_isAlphaNumeric(_peek())) {
              // 基数に応じた有効文字チェックがより正確
              String digit = _peek();
              // TODO: 基数に基づいた文字バリデーション (e.g., 2rなら0,1のみ)
              numBuffer.write(_advance());
            }
          } else {
            // Radix out of bounds, treat as symbol or parts of symbol
            // Revert numBuffer to only firstChar for symbol parsing
            numBuffer.clear();
            numBuffer.write(firstCharOrHash);
            // _current を戻す必要があるが複雑。ここでは基数失敗＝数値失敗としておく。
          }
        } catch (e) {
          /* Not a valid radix prefix, continue as decimal */
          // numBufferには数字が溜まっているので、それを10進数として処理継続
        }
      }
    }

    if (!isRadix) {
      // 16進数 (0x or 0X)
      bool isHex = false;
      if (firstCharOrHash == '0' && (_peek() == 'x' || _peek() == 'X')) {
        isHex = true;
        numBuffer.write(_advance()); // 'x' or 'X'
        while (_isHexDigit(_peek())) {
          numBuffer.write(_advance());
        }
      }
      // 8進数 (0で始まり、数字が続く。ただし、'.' 'e' '/' 'x' 'r'を含まない)
      else if (firstCharOrHash == '0' && _isOctalDigit(_peek())) {
        bool isOctal = true;
        // 読み進めながらチェック
        int tempCurrent = _current;
        String nextChars = "";
        while (_isOctalDigit(_source[tempCurrent])) {
          // 先読みで確認
          nextChars += _source[tempCurrent];
          tempCurrent++;
          if (tempCurrent >= _source.length) break;
          final charCheck = _source[tempCurrent];
          if (charCheck == '.' ||
              charCheck.toLowerCase() == 'e' ||
              charCheck == '/' ||
              charCheck.toLowerCase() == 'x' ||
              charCheck.toLowerCase() == 'r' ||
              !_isOctalDigit(charCheck) && _isDigit(charCheck)) {
            // 8,9は8進数ではない
            isOctal = false;
            break;
          }
        }

        if (isOctal) {
          while (_isOctalDigit(_peek())) {
            // 正式に消費
            numBuffer.write(_advance());
          }
        } else {
          // 10進数の0として処理継続
          while (_isDigit(_peek())) {
            // 0の後の数字 (e.g. 09)
            numBuffer.write(_advance());
          }
        }
      }
      // 10進数 (上記以外)
      else {
        // firstCharOrHash が [+-] の場合、最初の数字を読む
        if (firstCharOrHash == '+' || firstCharOrHash == '-') {
          if (_isDigit(_peek())) {
            // [+-] の後に数字がある
            numBuffer.write(_advance());
          } else {
            // [+-] のみ。これはシンボル。
            _symbol(firstCharOrHash);
            return;
          }
        }
        // 残りの整数部分
        while (_isDigit(_peek())) {
          numBuffer.write(_advance());
        }
      }

      // 小数点と指数部 (16進数や8進数、基数指定ではない場合)
      if (!isHex && !isRadix) {
        // 8進数の場合も小数や指数はない
        bool hasDecimal = false;
        if (_peek() == '.') {
          // Ensure it's not '..' (symbol) or '.method' (symbol part)
          // If the char after '.' is a digit, it's a decimal.
          if (_isDigit(_peekNext())) {
            hasDecimal = true;
            numBuffer.write(_advance()); // '.'
            while (_isDigit(_peek())) {
              numBuffer.write(_advance());
            }
          } else {
            // '.' の後に数字がない (e.g., "1.", "foo.bar")
            // これは数値の終わり。'.' は次のトークンになるか、シンボルの一部。
            // ここでは何もしない。ループは終わる。
          }
        }

        if (_peek() == 'e' || _peek() == 'E') {
          // 指数部の後に数字が必須
          if (_isDigit(_peekNext()) ||
              ((_peekNext() == '+' || _peekNext() == '-') &&
                  _isDigit(
                    _source[_current + 2 < _source.length
                        ? _current + 2
                        : _current /*dummy to avoid error, logic ensures digit*/],
                  ))) {
            numBuffer.write(_advance()); // 'e' or 'E'
            if (_peek() == '+' || _peek() == '-') {
              numBuffer.write(_advance());
            }
            while (_isDigit(_peek())) {
              numBuffer.write(_advance());
            }
          }
        }

        // Ratio (N/M) : 小数点や指数がない場合のみ
        if (!hasDecimal && (_peek() == 'e' || _peek() == 'E') == false) {
          if (_peek() == '/' && _isDigit(_peekNext())) {
            numBuffer.write(_advance()); // '/'
            // 分母の最初の数字
            if (_isDigit(_peek()))
              numBuffer.write(_advance());
            else {
              /*エラー: /の後に数字なし*/
            }
            while (_isDigit(_peek())) {
              numBuffer.write(_advance());
            }
          }
        }
      }
    } // end if !isRadix

    // サフィックス (N, M)
    String suffix = "";
    if (_peek() == 'N' || _peek() == 'M') {
      // Ensure it's not part of a Radix number's content like 36rN
      // For Radix, the loop for digits would have consumed N/M if they are valid digits for that base.
      // So, if we are here and see N/M, it's likely a suffix.
      // Exception: if the Radix was, e.g. 20 (up to J), and we have 20rK1N. N is part of value.
      // This needs care. Let's assume non-radix or hex for N/M suffixes primarily.
      // Or, if Radix/Hex, N/M are only suffixes if not valid digits for that base.
      // For simplicity: if isRadix or isHex, assume N/M are part of the number if they are valid hex/radix digits.
      // Otherwise, they are suffixes. This is an approximation.
      bool canBeSuffix = true;
      if (isRadix) {
        // Check if N or M is a valid digit for radixValue
        // This is complex, skip for now, assume it's a suffix unless already consumed.
      }
      if (canBeSuffix) {
        suffix = _advance();
        numBuffer.write(suffix);
      }
    }

    final lexeme = numBuffer.toString();
    // パース試行 (Clojureの挙動に合わせてより詳細なパースが必要)
    // ここでは簡易的に double, int, BigInt (Nサフィックス)
    try {
      if (isRadix) {
        String digitsPart = lexeme.substring(lexeme.toLowerCase().indexOf('r') + 1);
        literalValue = BigInt.parse(digitsPart, radix: radixValue); // ClojureはLongかBigInt
      } else if (lexeme.contains('/') && !lexeme.contains('.')) {
        // Ratio
        final parts = lexeme.split('/');
        if (parts.length == 2) {
          final num = BigInt.parse(parts[0]); // ClojureはLong/BigInt
          final den = BigInt.parse(parts[1]);
          if (den == BigInt.zero) {
            /* Error: Division by zero */
            literalValue = null;
          } else {
            // DartにはRatio型がない。doubleにするか、カスタムオブジェクト。
            // ここではdouble。ClojureはRatioを保持する。
            literalValue = num / den;
          }
        }
      } else if (suffix == 'N') {
        literalValue = BigInt.parse(lexeme.substring(0, lexeme.length - 1));
      } else if (suffix == 'M') {
        // DartにはBigDecimalがない。doubleで代用するかエラー。
        // ClojureはBigDecimal。ここではdoubleとしてパース。
        literalValue = double.tryParse(lexeme.substring(0, lexeme.length - 1));
      } else if (lexeme.contains('.') || lexeme.toLowerCase().contains('e')) {
        literalValue = double.tryParse(lexeme);
      } else {
        // Integer (10進, 16進, 8進)
        if (lexeme.startsWith('0x') || lexeme.startsWith('0X')) {
          literalValue = BigInt.parse(lexeme.substring(2), radix: 16);
        } else if (lexeme.startsWith('0') &&
            lexeme.length > 1 &&
            !lexeme.contains('.') &&
            !lexeme.toLowerCase().contains('e') &&
            !lexeme.contains('/') &&
            !lexeme.toLowerCase().contains('x') &&
            !lexeme.toLowerCase().contains('r')) {
          // Octal
          // Check if all digits are octal
          bool allOctal = true;
          for (int i = 1; i < lexeme.length; ++i) {
            if (!_isOctalDigit(lexeme[i])) {
              allOctal = false;
              break;
            }
          }
          if (allOctal)
            literalValue = BigInt.parse(lexeme.substring(1), radix: 8);
          else
            literalValue = BigInt.parse(lexeme); // e.g. 09 is decimal 9
        } else {
          literalValue = BigInt.parse(lexeme); // ClojureはLong/BigInt
        }
      }
    } catch (e) {
      // パース失敗
      literalValue = null; // エラーを示す
    }
    _addToken(TokenType.number, literalValue);
  }
}
