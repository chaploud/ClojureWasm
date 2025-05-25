// lib/src/reader/token.dart

/// Clojure TokenType Enum
///
/// leftParen, rightParen: ()
/// leftBracket, rightBracket: []
/// leftBrace, rightBrace: {}
/// nil: nil
/// boolean: true, false
/// string: "", "clojure", "\t \b \n \r \f \' \" \\ \u0041 \101"
/// number: 12, -12, 0xff, 077, 2r1010, 123N, -0.5, 3.14, 6.02e23, 3.14M, 22/7
/// character: \a, \u0041, \o12, \newline, \space, \tab, \formfeed, \backspace, \return
/// symbol: foo, my-ns/foo, cloure.math/cos
/// keyword: :foo, :my.ns/bar, ::baz, ::another-ns/qux
/// quote: '
/// syntaxQuote: `
/// unquote: ~
/// unquoteSplicing: ~@
/// deref: @
/// dispatch: #{}, #"pattern", #'var, #(), #_ignore
/// comment: ; comment
/// eof: end of file
enum TokenType {
  leftParen,
  rightParen,
  leftBracket,
  rightBracket,
  leftBrace,
  rightBrace,
  nil,
  boolean,
  number,
  string,
  character,
  symbol,
  keyword,
  quote,
  syntaxQuote,
  unquote,
  unquoteSplicing,
  deref,
  dispatch,
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
