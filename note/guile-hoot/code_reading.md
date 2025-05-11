# Guile Hootリーディングメモ

## プロジェクト概要

Guile Hootは、Scheme言語の処理系であるGuileのコードをWebAssembly（Wasm）に変換するためのプロジェクトです。Spritely Instituteによって開発されており、SchemeコードをWebブラウザなど様々なプラットフォームで動作させることを可能にします。

主な特徴：

- R7RS-small Schemeの全体をWebAssemblyにAhead-of-Time(AOT)コンパイル
- WebAssemblyの拡張機能（tail calls、garbage collection）を活用
- 独自のWebAssemblyツールチェーン（WAT（WebAssembly Text）パーサー、アセンブラ、ディスアセンブラ、インタプリタ等）を含む

## プロジェクト構造

プロジェクトは複数のコンポーネントで構成されています：

1. コンパイラフロントエンド（SchemeコードをCPS中間表現に変換）
2. コンパイラバックエンド（CPS中間表現をWebAssemblyに変換）
3. WebAssemblyツールチェーン（アセンブラ、パーサー、最適化など）
4. リフレクション機能（ホスト環境とWasm間の連携）
5. 標準ライブラリ

## WebAssemblyへの変換とデータ表現

### データ表現（ABI）

Schemeは動的型付け言語であるため、WebAssemblyの静的型システムにマッピングするための工夫が必要です：

- `SCM` unitype：すべてのScheme値を表現するための型で、WebAssemblyでは `(ref eq)` として表現
- 即値（fixnum、文字、真偽値など）：`(ref i31)` 値として符号化
- ヒープオブジェクト：複雑なデータ型（リスト、ベクター、文字列など）はWebAssemblyのGC機能を使った型付きオブジェクトとして表現

### 呼び出し規約とスタック管理

Guile Hootは、軽量な並行処理（限定継続）と可変引数をサポートするために、特殊な関数呼び出し方式を採用しています：

1. **テイル呼び出しのみ**：コンパイラはすべての関数呼び出しをテイル呼び出しに変換
2. **明示的なスタック**：非テイル呼び出しは、戻り値のためのライブ値と戻り継続をスタックにプッシュし、その後テイル呼び出しに変換
3. **動的スタック**：`dynamic-wind`のワインダー、プロンプト、フルイドバインディングなどを管理

この方式により、明示的なスタック表現を通じて限定継続のキャプチャと復元が可能になり、デバッガも実装できます。また、内部ループのような呼び出しのない部分は直接スタイルのコンパイルと同様に高速に実行できます。

### コンパイルパイプライン

Guile Hootのコンパイルパイプラインは以下の流れで構成されています：

1. **フロントエンド**：Schemeコード → Tree-IL → CPS（継続渡しスタイル）中間表現
2. **バックエンド**：CPS → WebAssemblyモジュール
3. **最適化**：WebAssemblyレベルでの最適化（ローカル変数の削減、スタックマシンの効率的な利用など）
4. **リンク**：WebAssemblyモジュールの結合

各段階での重要なファイル：

- `module/hoot/compile.scm`: コンパイルプロセスのエントリーポイント
- `module/hoot/frontend.scm`: フロントエンド部分
- `module/hoot/backend.scm`: バックエンド部分（CPS → Wasm変換）
- `module/wasm/optimize.scm`: WebAssemblyレベルでの最適化
- `module/wasm/lower.scm`: 高レベルなWasmから低レベルなWasmへの変換

## WebAssemblyツールチェーン

Guile Hootは、独自のWebAssemblyツールチェーンを含んでいます：

1. **WATパーサー**（`module/wasm/parse.scm`）：WebAssembly Text形式をパース
2. **アセンブラ**（`module/wasm/assemble.scm`）：Guileレコードをバイナリ形式に変換
3. **ディスアセンブラ**：バイナリからテキスト表現への変換
4. **インタープリタ**（`module/wasm/vm.scm`）：WebAssemblyを直接解釈実行

## 最適化技術

Guile Hootは複数レイヤーでの最適化を行います：

1. **Tree-IL最適化**：部分評価など高レベルな最適化
2. **CPS最適化**：共通部分式除去、デッドコード除去
3. **WebAssembly最適化**：
   - ローカル変数の削減（スタックを活用）
   - パケット化と再配置による最適化
   - キャストの最適化（型情報を活用した`ref.cast`の削減）

`module/wasm/optimize.scm`では、WebAssemblyのスタックマシンの特性を活かすために、
命令シーケンスを「パケット」という単位に分解し、それらを再配置・合体させることで
ローカル変数の使用を減らし、スタックを通じたデータフローを促進しています。

## ホスト環境との連携

WebAssemblyはホスト環境（ブラウザやNode.jsなど）に依存する場合があります。
特にBigIntの実装などの機能については、ホスト環境の機能を利用しています。

リフレクション機能はこの連携を担当し、以下のコンポーネントで構成されています：

1. `reflect.js`：JavaScriptホスト環境向けのリフレクションライブラリ
2. `reflect.wasm`：WebAssemblyとJavaScriptの間のインピーダンスマッチング
3. `wtf8.wasm`：文字列エンコーディング変換のサポート

## コードの詳細分析

### コンパイラフロントエンド

`module/hoot/compile.scm`を分析すると、Guile Hootコンパイルプロセスは以下のようになっています：

1. Scheme式を`scheme->sealed-tree-il`関数でTree-IL中間表現に変換
2. Tree-ILをCPS（継続渡しスタイル）中間表現に変換
3. CPSをWasmに変換する`hoot/backend.scm`へ渡す

フロントエンドはGuileの既存コンパイラインフラを活用しており、特にTree-ILとCPS変換は標準のGuileコンパイラと同様のプロセスを踏んでいます。

### バックエンド (CPS→Wasm)

`module/hoot/backend.scm`は、CPSからWebAssemblyへの変換を担当します。このファイルは約2900行と大きく、CPSの各コンストラクトをどのようにWasmに変換するかのロジックが含まれています。主な特徴は：

1. **継続渡し形式の維持**：CPSの継続渡しスタイルを維持しながらWasmに変換
2. **型情報の活用**：CPS中間表現に含まれる型情報を利用して効率的なコードを生成
3. **テイルコール変換**：すべての関数呼び出しをテイルコールに変換して継続を明示的に扱う

### WebAssembly最適化パス

`module/wasm/optimize.scm`でのWasm最適化は非常に興味深いアプローチを取っています：

1. **パケット化**：Wasm命令をパケットという単位にグループ化

```scheme
(define-record-type <packet>
  (make-packet code uses defs effect)
  packet?
  (code packet-code)   ; list of inst
  (uses packet-uses)   ; list of local id, <func-sig> order
  (defs packet-defs)   ; list of local id, <func-sig> order
  (effect packet-effect)) ; <effect>
```

2. **効果分析**：各パケットの副作用（メモリ操作、制御フロー等）を追跡

3. **再配置と結合**：パケットの依存関係と副作用に基づいて再配置・結合し、ローカル変数の使用を最小化

最適化パスの基本的な考え方は「WebAssemblyのスタックマシンの特性を活かし、ローカル変数を経由せずにスタックでデータをパイプラインすること」です。

### WebAssemblyインタプリタ

`module/wasm/vm.scm`は、Guile内でWebAssemblyを直接解釈実行するためのVMを実装しています。このVMは主に開発とテスト目的で使われ、ブラウザなどの本番環境に依存せずにWasmコードをテストできます。

```scheme
(define-module (wasm vm)
  #:export (validate-wasm
            load-and-validate-wasm
            validated-wasm?
            validated-wasm-ref
            ;; ... その他の関数
            ))
```

### リフレクション層の詳細

リフレクション層は3つの主要なコンポーネントから構成されています：

1. **reflect.js** (JavaScriptインターフェース)：
   - Scheme値をJavaScriptで扱いやすい形式に変換
   - WebAssemblyからエクスポートされた関数を呼び出すためのラッパー
   - 様々なScheme型（Pair, Vector, String等）のJavaScriptクラス表現

2. **reflect.wasm** (型情報・変換層)：
   - Scheme値の型判別機能 (`describe`関数)
   - Scheme値のフィールドアクセス
   - JavaScript→Scheme値の変換

3. **wtf8.wasm** (文字列エンコーディング処理)：
   - WTF-8エンコーディングの処理
   - 文字列操作のサポート

`reflect.js`は特に興味深く、SchemeのすべてのデータタイプをJavaScriptクラスで表現しています：

```javascript
class Char { /* 文字表現 */ }
class Complex { /* 複素数表現 */ }
class Fraction { /* 分数表現 */ }
class Pair extends HeapObject { /* コンスセル */ }
class Vector extends HeapObject { /* ベクター */ }
// ...他のデータ型
```

### プリミティブ型の表現

WasmのGC拡張によりサポートされる型表現：

1. `(ref i31)` : 即値（31ビット整数、文字、真偽値など）
2. `(ref eq)` : 参照型のベース
3. 構造体・配列型 : リスト、ベクター、文字列などの複合データ構造

`reflect.wat`では、これらの型を判別・操作する関数が提供されています。たとえば、`describe`関数は与えられたScheme値の型を判別します。

## 実行フロー

Schemeプログラムを実行する全体のフローを整理すると：

1. **コンパイル時**：
   - Scheme → Tree-IL → CPS → Wasm変換
   - 様々な最適化パスの適用（Tree-IL、CPS、Wasm各レベル）
   - Wasmバイナリとリフレクションコンポーネントのリンク

2. **実行時**：
   - ブラウザなどのホスト環境がWasmモジュールをロード
   - `reflect.js`がホスト環境とWasmのインターフェースを提供
   - Wasm内でSchemeプログラムが実行され、結果がホスト環境に返される

特に実行時にはテイルコール最適化と継続の明示的な管理により、SchemeのすべてのセマンティクスがWebAssembly上で再現されています。

## コードレベルでの最適化戦略

### WebAssemblyパケット化と最適化

`module/wasm/optimize.scm`を詳しく分析すると、WebAssemblyコードの最適化に独特のアプローチを取っていることがわかります。Guile Hootの最適化プロセスは以下の段階で行われています：

#### パケット化 (Packetization)

WebAssemblyのスタックベースの命令をパケットという単位にグループ化します。パケットはコード、入力（uses）、出力（defs）、そして副作用（effect）から構成されます：

```scheme
(define-record-type <packet>
  (make-packet code uses defs effect)
  packet?
  (code packet-code)   ; list of inst
  (uses packet-uses)   ; list of local id, <func-sig> order
  (defs packet-defs)   ; list of local id, <func-sig> order
  (effect packet-effect)) ; <effect>
```

#### 効果分析 (Effect Analysis)

各パケットが持つ副作用を分析します：

- メモリアクセスの読み書き
- コントロールフローの変更（ジャンプ、条件分岐）
- 外部関数呼び出し
- 例外処理

この分析により、どのパケットが安全に入れ替えや結合ができるかを判断します。

#### パケットの再配置と結合 (Reordering and Coalescing)

パケット間の依存関係と副作用に基づいて、安全に再配置・結合できるパケットを特定します：

```scheme
;; パケットの結合例（optimize.scm より抜粋・簡略化）
(define (coalesce-packets a b)
  ;; 2つのパケットが安全に結合できるか検証
  (and (not (effects-conflict? (packet-effect a) (packet-effect b)))
       ;; 結合する場合、新しいパケットを作成
       (make-packet
        (append (packet-code a) (packet-code b))
        (append (packet-uses a)
                (filter (lambda (use)
                         (not (member use (packet-defs a))))
                        (packet-uses b)))
        (append (filter (lambda (def)
                         (not (member def (packet-uses b))))
                        (packet-defs a))
                (packet-defs b))
        (effects-union (packet-effect a) (packet-effect b)))))
```

#### スタックフロー最適化 (Stack Flow Optimization)

結合されたパケットをローカル変数をできるだけ使わず、WebAssemblyのスタックを活用する形で再構築します。これにより、ローカル変数のセット・ゲットの命令を減らし、コードサイズと実行速度を最適化します。

### CPS（継続渡しスタイル）からWebAssemblyへの変換

`module/hoot/backend.scm`は、GuileのCPS形式をWebAssemblyに変換する重要なコンポーネントです。この変換では以下のポイントが重要です：

#### 継続の明示的な表現

Schemeの強力な機能の一つは継続（continuation）ですが、これをWebAssemblyで表現するためには特別な手法が必要です：

```scheme
;; backend.scmからの抜粋（簡略化）
(define (compile-continuation k vars)
  ;; 継続をWasmの関数として表現
  (make-func
   (make-param-locals vars)
   (compile-term (continuation-term k))))
```

**テイル呼び出し最適化**

すべての関数呼び出しをテイル呼び出しに変換することで、Schemeの無制限再帰を効率的に実装しています：

```scheme
;; 関数呼び出しのテイル呼び出し変換（概念コード）
(define (compile-call proc args)
  `(return_call ,proc ,@args))
```

**クロージャの表現**

Schemeの関数はクロージャとして、自由変数を捕捉できます。WebAssemblyではこれを構造体として表現しています：

```scheme
;; クロージャ用の構造体型定義例
(define closure-type
  (struct-type `((func (ref $func))
                 ,@(map (lambda (var) `(,var ,(variable-type var)))
                        free-vars))))
```

## 実行時サポートのための高度な機能

### reflect.jsの詳細分析

`reflect.js`は、SchemeオブジェクトとJavaScript環境の間の橋渡しをする重要なコンポーネントです。このファイルには以下のような機能が含まれています：

**Schemeデータ型のJavaScriptクラス表現**

```javascript
// 基本的なデータ型
class Char { /* 文字表現 */ }
class Complex { /* 複素数表現 */ }
class Fraction { /* 分数表現 */ }

// コレクション型
class Pair extends HeapObject { /* コンスセル */ }
class MutablePair extends Pair { /* 可変コンスセル */ }
class Vector extends HeapObject { /* ベクター */ }
class MutableVector extends Vector { /* 可変ベクター */ }
```

**プロシージャのラッピング**

Scheme関数をJavaScriptから呼び出せるようにラップする機能があります：

```javascript
function wrap_procedure(reflector, proc, numParams = 0) {
    return function(...args) {
        // 引数の型変換
        const convertedArgs = args.map(val => js_to_scm(reflector, val));
        // Schemeプロシージャの呼び出し
        const result = reflector.call(proc, convertedArgs.length, ...convertedArgs);
        // 結果の型変換
        return scm_to_js(reflector, result);
    };
}
```

**型変換ユーティリティ**

JavaScript値とScheme値の間の変換を行うユーティリティ関数群：

```javascript
function scm_to_js(reflector, val) {
    // Scheme値をJavaScript値に変換
    const type = reflector.describe(val);
    switch (type) {
        case "fixnum": return reflector.fixnum_value(val);
        case "flonum": return reflector.flonum_value(val);
        // ... 他の型の変換 ...
    }
}

function js_to_scm(reflector, val) {
    // JavaScript値をScheme値に変換
    if (typeof val === "number") {
        if (Number.isInteger(val) && val >= -2**29 && val < 2**29)
            return reflector.make_fixnum(val);
        return reflector.make_flonum(val);
    }
    // ... 他の型の変換 ...
}
```

### wtf8.watの特別な役割

`wtf8.wat`はUTF-8文字列の処理を担当する特殊なWebAssemblyモジュールです：

```wat
;; WTF-8デコーダーの状態遷移テーブル
(data
 (memory $decoder)
 (i32.const 0)
 ;; 遷移テーブル（ASCII部分）
 #vu8(0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0   ;; 00-0F
      0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0 ;; 10-1F
      ;; ... 省略 ...
     ))
```

このモジュールはJavaScriptのUnicodeとSchemeの文字列表現の間の変換を担当しています。WTF-8はUTF-8を拡張したエンコーディングで、サロゲートペアを単独で表現できる特徴があります。

## その他の重要なコンポーネント

### モジュールシステム

Guile Hootは、Guileのモジュールシステムをサポートするために特別な処理を行っています：

1. **モジュールの動的読み込み**
2. **シンボルの解決と名前空間管理**
3. **モジュールのエクスポート・インポートの実装**

### テスト体系

`test/`ディレクトリには、Guile Hootの様々な側面をテストする豊富なテストスイートが含まれています：

1. **データ型のテスト**：基本型、複素数、分数などのテスト
2. **コントロールフローのテスト**：継続、プロンプト、例外処理のテスト
3. **モジュールシステムのテスト**：モジュールのロードとシンボル解決のテスト
4. **FFIのテスト**：外部関数インターフェースのテスト

テストは、マシンで生成したWasmコードが正しく動作することを確認するために重要な役割を果たしています。

## まとめ

Guile Hootは、Scheme（特にGuile）からWebAssemblyへのコンパイラであり、SchemeのすべてのセマンティクスをWasmで正確に再現しようとする野心的なプロジェクトです。特に重要な設計目標は：

1. **完全なSchemeセマンティクスの再現**：継続、プロンプト、動的型など
2. **効率的なコードの生成**：最適化を通じて小さく高速なWasmコードの生成
3. **ホスト環境との統合**：ブラウザやNode.jsなどとの連携

これらの目標を達成するために、プロジェクトは複数の中間表現を経由する複雑なコンパイルパイプラインを実装し、独自のWasmツールチェーンを構築しています。また、リフレクション層を通じてWasmとJavaScript環境の統合を実現しています。
