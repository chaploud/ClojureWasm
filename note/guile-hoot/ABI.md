# Guile on WebAssembly: ABI

目次

## データ表現

### `SCM` ユニタイプ

Schemeは型付けされていない言語であり、あらゆる値を共通の `SCM` ユニタイプに格納できます。特定の `SCM` が保持する具体的な値の種類は、値を調べることで判断できます。（もちろん、Guileのコンパイラは値をアンボックス化でき、場合によっては生の `f64` 値などで動作することもあります。しかし、一般的なケースに対応する必要があります。）

私たちは [GC MVP](https://www.google.com/search?q=https://github.com/WebAssembly/gc/blob/master/proposals/gc/MVP.md) をターゲットにしているため、`SCM` を `(ref eq)` として表現できます。この型にヌル許容性を許可する必要はありません。

### 即値

すべての即値（fixnum、文字、ブール値など）は `(ref i31)` 値としてエンコードされます。2\<sup\>31\</sup\> 個の可能な値は、タギングによって分割されます。この分割は、[ネイティブGuileが行うこと](https://www.google.com/search?q=http://git.savannah.gnu.org/cgit/guile.git/tree/module/system/base/types/internal.scm%3Fh%3Dwip-tailify%23n101) と似ていますが、最下位の0ビットが省略され、いくつかの中間0ビットが削除されている点が異なります。したがって、fixnumの範囲は、32ビットターゲットのネイティブGuileと同じく \[-2\<sup\>29\</sup\>, 2\<sup\>29\</sup\>-1\] です。

ここで、[`i31ref` がMVP以降に延期されるリスク](https://www.google.com/search?q=%5Bhttps://github.com/WebAssembly/gc/issues/320%5D\(https://github.com/WebAssembly/gc/issues/320\)) があることに注意してください。しかし、これはありそうにありません。

### ヒープオブジェクト

ネイティブGuileでは、即値とヒープオブジェクトがあります。即値は、その内容を `SCM` のビットに直接持ちます。ヒープオブジェクトは、ヒープへのポインタである `SCM` 値です。オブジェクトの型は、`SCM` 値が指すメモリの最初のワードにエンコードされます。

WebAssemblyでは、ガベージコレクションされるオブジェクトも型識別子に関連付けることができ、WebAssemblyプログラムはこれらをイントロスペクトして、例えば値が特定の型を持つ場合にラベルに分岐することができます。さまざまなSchemeデータ型を実装する際には、これらの組み込み機能を使用します。

## 呼び出し規約

制限継続と可変引数カウントによる軽量並行性をサポートするために、Guile-on-WebAssemblyは標準のWebAssembly関数呼び出しメカニズムを特殊な方法で使用します。

継続の側では、基本的な考え方として、GuileからWebAssemblyへのコンパイラがプログラムを変換し、すべての呼び出しが末尾呼び出しになるようにします。関数内の非末尾呼び出しは、呼び出し元がリターンポイントに流れるライブ値を明示的なスタックにプッシュし、リターン継続をプッシュしてから被呼び出し元を末尾呼び出しするように変換されます。関数からのリターンは、被呼び出し元がスタックからリターン継続をポップし、それを末尾呼び出しするように変換されます。詳細については、[`wip-tailify` Guileブランチの `tailify.scm`](https://www.google.com/search?q=%5Bhttp://git.savannah.gnu.org/cgit/guile.git/tree/module/language/cps/tailify.scm%3Fh%3Dwip-tailify%23n19%5D\(http://git.savannah.gnu.org/cgit/guile.git/tree/module/language/cps/tailify.scm%3Fh%3Dwip-tailify%23n19\)) を参照してください。

このアプローチの利点は、明示的なスタック表現を使用することで、制限継続をキャプチャして復元でき、ホストWebAssemblyシステムではなくGuileによって構造を検査できる継続の観点からデバッガを作成できることです。変換は最小限であるため、例えば呼び出しのない内部ループは、直接的なスタイルのコンパイルと同じくらい高速です。

（この呼び出し規約は、[型付き継続またはファイバーベースのスタック切り替え提案](https://github.com/WebAssembly/stack-switching) のいずれかによって不要になる可能性がありますが、これらの機能のいずれかが2025年頃までにコンセンサスに達して出荷されるとは考えていません。）

さらに、Guile関数は可変個の引数を受け入れることができますが、WebAssembly関数は固定型を持ちます。一般的なケースでは、グローバルな引数渡し配列を介して引数を渡す必要がある場合があります。最初のいくつかの引数はパラメータとして渡すことができます。引数の数も関数パラメータとして渡されます。すべての呼び出しは末尾呼び出しであるため、この規約は値の返しにも適用されます。

### 動的スタック

動的スタックは、スタックフレームを `dynamic-wind` ワインダー、プロンプト、個々の流体束縛、および動的状態（流体束縛のセット全体）に関連付けます。まだ指定されていません。本来、アップストリームのGuileはここで継続マークを使用すべきですが、まだそうしていません。

### 動的状態

流体とスレッドの詳細については後述しますが、基本的にGuileはいくつかの動的スコープ変数の現在の値のキャッシュを保持する必要があります。まだ指定されていません。

### リターンスタック

リターンスタックは、スタック割り当てされた継続用です。基本的には、ソースプログラムの非末尾呼び出しのリターンポイントに対応するものです。`SCM` 値、生の `i64` および `f64` 値、および `(ref func)` リターン継続用に別々のスタックがありますが、具体的な表現はまだ指定されていません。

## 型定義

### 即値データ型

即値は、fixnum、文字、または奇妙なものです。

すべての即値は `(ref i31)` としてエンコードされます。

`i32` ペイロードは、`i31.get_s` を使用して符号拡張によって `(ref i31)` から抽出されます。

ペイロードの最下位ビットが `#b0` の場合、値はfixnumであり、その符号付き整数値はペイロードの上位ビットにあります。

ペイロードの最下位2ビットが `#b11` の場合、値は文字であり、そのコードポイントはペイロードの上位ビットにあります。コードポイントは2\<sup\>21\</sup\> までしか上がらないため、符号ビットは常に設定されません。

それ以外の場合、可能なペイロードは次のとおりです。

- `#b000001`: 1: `#f`
- `#b000101`: 5: `nil`
- `#b001101`: 13: `'()` (null)
- `#b010001`: 17: `#t`
- `#b100001`: 33: 未指定の値
- `#b101001`: 41: EOF
- `#b111001`: 57: 未定義の値（内部的に使用）

いくつかの一般的な奇妙なもののテスト：

- `null?`: nullまたはnilをチェックします。 `(= (logand payload #b110111) #b000101)`
- `false?`: falseまたはnilをチェックします。 `(= (logand payload #b111011) #b000001)`
- `elisp-false?`: false、nil、またはnullをチェックします。 `(= (logand payload #b110011) #b000001)`

### ユーティリティデータ型

```wat
(type $raw-immutable-bitvector (array i32))
(type $raw-immutable-bytevector (array i8))

(type $raw-bitvector (array (mut i32)))
(type $raw-bytevector (array (mut i8)))
(type $raw-scmvector (array (mut (ref eq))))
```

### 継続型

tailify変換によって残余化された関数は、可変個の引数を取ります。取る値の数は、引数として関数に渡されます。最初の3つの引数はパラメータで渡され、追加の引数はグローバル配列を介して渡されます。関数が3つ未満のパラメータを持つ場合、引数として任意の値、例えば `(i31.new (i32.const 0))` を渡すことができます。

すべてをtailifyするため、すべての呼び出しは末尾呼び出しであり、したがって戻り値はありません。

```wat
(type $kvarargs (func (param $nargs i32)
                      (param $arg0 (ref eq))
                      (param $arg1 (ref eq))
                      (param $arg2 (ref eq))
                      (result)))
```

### ヒープ型

`(ref i31)` として表現されないすべてのGuileオブジェクトは「ヒープオブジェクト」です。これらのオブジェクトはすべて `$heap-object` のサブタイプです。

```wat
(type $void-struct (struct))
(type $heap-object
  (sub $void-struct
    (struct
      (field $hash (mut i32)))))
```

Guileが使用する具体的な種類のオブジェクト（約20種類）ごとにサブタイプがあります。

WebAssembly型システムの詳細として、通常、同じ形状を持つ2つの型は同等と見なされ、したがって区別できません。同じ形状を持つGuileオブジェクトが存在する場合があります。ただし、「ハイブリッド公称型付け」機能を使用して、一部が同じ形状を持つ場合でも、型が区別されるように宣言します。すべての型を `rec` ブロックでラップすることにより、単純な `ref.test` で動的な型チェックを実行できるようにします。

シンボルとキーワードの場合、`$hash` フィールドは、基になる文字列のstring-hashに基づいて積極的に計算されます。他のデータ型の場合、ハッシュは遅延計算されます。ハッシュ0は、初期化されていないハッシュを示します。ハッシュが初期化されている場合、ビット0は常に設定されます。それ以外の場合、即値については、単純なビット混合ハッシュ関数があります。

#### ホスト機能への参照

```wat
(type $extern-ref
  (sub $heap-object
    (struct
      (field $hash (mut i32))
      (field $val (ref extern)))))
```

ホストからの参照型付き値を参照したい場合があるため、1つのデータ型は `$extern-ref` です。

#### ヒープ数

```wat
(type $heap-number
  (sub $heap-object
    (struct
      (field $hash (mut i32)))))
```

非fixnumが実際に数値であることを迅速に確認する必要がある場合に備えて、ヒープ数のスーパータイプがあります。次に、具体的なヒープ数型があります。

```wat
(type $bignum
  (sub $heap-number
    (struct
      (field $hash (mut i32))
      (field $val (ref extern)))))
(type $flonum
  (sub $heap-number
    (struct
      (field $hash (mut i32))
      (field $val f64))))
(type $complex
  (sub $heap-number
    (struct
      (field $hash (mut i32))
      (field $real f64)
      (field $imag f64))))
(type $fraction
  (sub $heap-number
    (struct
      (field $hash (mut i32))
      (field $num (ref eq))
      (field $denom (ref eq)))))
```

#### ペア

```wat
(type $pair
  (sub $heap-object
    (struct
      (field $hash (mut i32))
      (field $car (mut (ref eq)))
      (field $cdr (mut (ref eq))))))
```

`$pair` のサブタイプである `$mutable-pair` もあり、同じフィールドを持ちます。`car` はオブジェクトが `$pair` であることを要求しますが、`set-car!` は `$mutable-pair` でもある `$pair` 値のサブセットを要求します。

#### ベクタ

```wat
(type $vector
  (sub $heap-object
    (struct
      (field $hash (mut i32))
      (field $vals (ref $raw-scmvector)))))
```

`$vector` のサブタイプである `$mutable-vector` もあり、同じフィールドを持ちます。

ベクタの長さは、`$vals` フィールドで `array.length` を使用して取得できます。

#### バイトベクタ

```wat
(type $bytevector
  (sub $heap-object
    (struct
      (field $hash (mut i32))
      (field $vals (ref $raw-bytevector)))))
```

`$bytevector` のサブタイプである `$mutable-bytevector` もあり、同じフィールドを持ちます。

バイトベクタの長さは、`$vals` フィールドで `array.length` を使用して取得できます。

#### ビットベクタ

通常、生の `i32` 配列のストレージスペースよりも小さい明示的な長さが必要です。

```wat
(type $bitvector
  (sub $heap-object
    (struct
      (field $hash (mut i32))
      (field $len i32)
      (field $bits (ref $raw-bitvector)))))
```

`$bitvector` のサブタイプである `$mutable-bitvector` もあり、同じフィールドを持ちます。

#### 文字列

```wat
(type $string
  (sub $heap-object
    (struct
      (field $hash (mut i32))
      (field $str (mut (ref string))))))
```

文字列表現を `(ref string)` にするだけでよいのですが、[`stringref` は `eqref` のサブタイプではありません](https://www.google.com/search?q=%5Bhttps://github.com/WebAssembly/stringref/issues/20%5D\(https://github.com/WebAssembly/stringref/issues/20\))。したがって、文字列をタグ付き構造体でラップする必要があります。しかし、これにより、hashqフィールドを持たせたり、文字列を（内容を置き換えることで）変更したりする可能性も得られます。

`$string` のサブタイプである `$mutable-string` もあり、同じフィールドを持ちます。

#### 手続き

```wat
(type $proc
  (sub $heap-object
    (struct
      (field $hash (mut i32))
      (field $func (ref $kvarargs)))))
```

手続きは関数の別名にすぎません。`$proc` はタグ付き関数です。

一部の関数は自由変数のセットをクロージャします。それらについては、`$proc` のサブタイプがあります。

```
(type $closure1
  (sub $proc
    (struct
      (field $hash (mut i32))
      (field $func (ref $kvarargs))
      (field $free0 (ref eq)))))
(type $closure2
  (sub $proc
    (struct
      (field $hash (mut i32))
      (field $func (ref $kvarargs))
      (field $free0 (ref eq))
      (field $free1 (ref eq)))))
;; ...
```

クロージャ型のセットは、コンパイルされるコードが必要とするものによって異なり、区別される型の `rec` ブロックの一部ではありません。

また、将来、WebAssemblyはそれ自体がクロージャであるfuncrefをサポートすることに注意してください。その場合、個別の `$closureN` 型を回避し、データをfuncrefに直接格納できます。

#### シンボルとキーワード

```wat
(type $symbol
  (sub $heap-object
    (struct
      (field $hash (mut i32))
      (field $name (ref string)))))

(type $keyword
  (sub $heap-object
    (struct
      (field $hash (mut i32))
      (field $name (ref $symbol)))))
```

シンボルのハッシュを計算する方法はまだ決定されていません。

#### 変数とアトミックボックス

```wat
(type $variable
  (sub $heap-object
    (struct
      (field $hash (mut i32))
      (field $val (mut (ref eq))))))
(type $atomic-box
  (sub $heap-object
    (struct
      (field $hash (mut i32))
      (field $val (mut (ref eq))))))
```

WebAssemblyは複数のスレッドをサポートしますが、GCオブジェクトのマルチスレッドサポートはないため、当面の間、アトミックボックスはアトミック操作を使用する必要はありません。

#### ハッシュテーブル

Schemeで実装された単純なバケットアンドチェーンハッシュテーブルを使用します。

```wat
(type $hash-table
  (sub $heap-object
    (struct
      (field $hash (mut i32))
      (field $size (mut (ref i31)))
      (field $buckets (ref $vector)))))
```

#### 弱参照テーブル

```wat
(type $weak-table
  (sub $heap-object
    (struct
      (field $hash (mut i32))
      (field $val (ref extern)))))
```

弱参照テーブルによって保持される外部値は、ホスト提供の弱参照マップです。

#### 動的状態

```wat
(type $fluid
  (sub $heap-object
    (struct
      (field $hash (mut i32))
      (field $init (ref eq)))))
(type $dynamic-state
  (sub $heap-object
    (struct
      (field $hash (mut i32))
      (field $val (ref extern)))))
```

ネイティブGuileでは、流体は本質的にキーであり、動的状態はすべての流体をその値にマッピングする弱参照ハッシュテーブルです。実行時には、流体値へのより高速なアクセスのためにスレッドごとのキャッシュがあります。流体のためのランタイムサポートルーチンがいくつか必要になります。

#### 構文とマクロ

```wat
(type $syntax
  (sub $heap-object
    (struct
      (field $hash (mut i32))
      (field $expr (ref eq))
      (field $wrap (ref eq))
      (field $module (ref eq))
      (field $source (ref eq)))))
```

`eval` を含まないモジュールに対して `psyntax` をWebAssemblyにコンパイルすることを回避できることを心から願っています。それでも、`read-syntax` は構文オブジェクトを生成でき、これはソース情報をオブジェクトに関連付ける優れた方法です。これはネイティブGuileの型であるため、Guile-on-WebAssemblyのためにスペースを確保することは理にかなっていると思います。

ネイティブGuileには構文トランスフォーマー用の `scm_tc16_macro` もあり、これもいずれ実装する必要があります。

#### 多次元配列

この最初のバージョンでは、これらについては後回しにします。Schemeでの配列の書き換えの状態についてDaniel Llodaに確認する必要があります。

#### ポート

ネイティブGuileがポートを表現する方法からインスピレーションを得ています。ただし、WASI環境とWeb環境の両方で、I/Oルーチンはすべてブロックする代わりにプロミスを返すことができると想定できるため、例えば読み取りまたは書き込み待機FDの明示的なサポートは必要ありません。代わりに、純粋なSchemeの[中断可能なポート実装](https://www.google.com/search?q=http://git.savannah.gnu.org/cgit/guile.git/tree/module/ice-9/suspendable-ports.scm%3Fh%3Dwip-tailify) を使用すると想定できるため、制限継続の中断と再開は問題なく機能します。

また、ポートでのテキストI/OのUTF-8エンコーディングを簡略化して想定することもできます。

```wat
(type $port-type
  (struct
    (field $name (ref string))
    ;; guileではこれらは (port, bv, start, count) -> size_t
    (field $read (ref null $proc)) ;; より洗練された型を持つ可能性がある
    (field $write (ref null $proc))
    (field $seek (ref null $proc)) ;; (port, offset, whence) -> offset
    (field $close (ref null $proc)) ;; (port) -> ()
    (field $get-natural-buffer-sizes (ref null $proc)) ;; port -> (rdsz, wrsz)
    (field $random-access? (ref null $proc)) ;; port -> bool
    (field $input-waiting (ref null $proc)) ;; port -> bool
    (field $truncate (ref null $proc)) ;; (port, length) -> ()
    ;; GuileにはGOOPSクラスもここにある。
    ))
(type $port
  (sub $heap-object
    (struct
      (field $hash (mut i32))
      (field $pt (ref $port-type))
      (field $stream (mut (ref eq)))
      (field $file_name (mut (ref eq)))
      (field $position (ref $pair))
      (field $read_buf (mut (ref eq))) ;; 5要素のベクタ
      (field $write_buf (mut (ref eq))) ;; 5要素のベクタ
      (field $write_buf_aux (mut (ref eq))) ;; 5要素のベクタ
      (field $read_buffering (mut i32))
      (field $refcount (mut i32))
      (field $rw_random (mut i8))
      (field $properties (mut (ref eq))))))
```

これらのさまざまなフィールドの意味はネイティブGuileと同じです。ポート表現は公開API/ABIではないため、この情報を見つけるには少し調べる必要があります。また、ここではかなりのランタイム作業が必要です。

ネイティブGuileには「port-with-print-state」データ型もあります。これが最終的に必要になるかどうかは不明です。おそらく不要でしょう。

#### 構造体

```wat
(type $struct
  (sub $heap-object
    (struct
      (field $hash (mut i32))
      (field $vtable (mut (ref null $vtable))))))
(type $vtable
  (sub $struct
    (struct
      (field $hash (mut i32))
      (field $vtable (mut (ref null $vtable)))
      (field $field0 (mut (ref eq)))
      (field $field1 (mut (ref eq)))
      (field $field2 (mut (ref eq)))
      (field $field3 (mut (ref eq))))))
```

Guileの構造体は、レコードとオブジェクト指向を実装する基本的な機能です。それらのvtableも少なくとも4つのフィールドを持つ構造体であるという奇妙さがあります。

`$struct` と `$vtable` の定義は `rec` ブロック内にあります。プログラムが必要とする特定の構造体型は、必要に応じて残余化されます。構造体に4つを超えるフィールドがある場合、それらをヒープベクタに格納する場合があります。

```
(type $struct1
  (sub $struct
    (struct
      (field $hash (mut i32))
      (field $vtable (mut (ref null $struct4)))
      (field $field0 (mut (ref eq))))))
(type $struct2
  (sub $struct
    (struct
      (field $hash (mut i32))
      (field $vtable (mut (ref null $struct4)))
      (field $field0 (mut (ref eq)))
      (field $field1 (mut (ref eq))))))
(type $struct3
  (sub $struct
    (struct
      (field $hash (mut i32))
      (field $vtable (mut (ref null $struct4)))
      (field $field0 (mut (ref eq)))
      (field $field1 (mut (ref eq)))
      (field $field2 (mut (ref eq))))))
(type $struct4
  (sub $struct
    (struct
      (field $hash (mut i32))
      (field $vtable (mut (ref null $struct4)))
      (field $field0 (mut (ref eq)))
      (field $field1 (mut (ref eq)))
      (field $field2 (mut (ref eq)))
      (field $field3 (mut (ref eq))))))
(type $structN
  (sub $struct
    (struct
      (field $hash (mut i32))
      (field $vtable (mut (ref null $struct4)))
      (field $field0 (mut (ref eq)))
      (field $field1 (mut (ref eq)))
      (field $field2 (mut (ref eq)))
      (field $field3 (mut (ref eq)))
      (field $tail (ref $raw-scmvector)))))
```

## 未サポートの型

弱参照ベクタはまだサポートされていません。

正規表現：まだサポートされていません。JS呼び出しになるでしょう。

乱数状態。

文字セット。

第一級スレッド、ミューテックス、および条件変数。

第一級の制限継続と非制限継続の表現は現在指定されていません。（ただし、すべてのスタックのスライスになります。）

## 未解決の質問

構造体型に `final` で注釈を付けるべきでしょうか？ MVPドキュメントでは言及されていますが、binaryenはサポートしていないようです。

## JS API

Wasm GC値（したがってGuile-on-Wasm値）はJavaScriptに対して不透明です。参照によってJSを通過できますが、JSがそれらに対して独自に何かを行う場合は、例えばfixnumの整数をアンパックするために、JSとの間で明示的な変換が必要です。これを行うためのサイドWasmライブラリがあります。
