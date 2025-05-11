# ClojureWasm開発アイデア

## 主目的

- あらゆる環境におけるClojureの実行
- Wasm統合によりWasmの資産を活用できる
- ハイパフォーマンスかつインタプリタ言語(オリジナルClojureを上回る)
- Clojureがwasm上の構造で動いている
  - PersistentArray
  - immutable
  - Garbage Collection
- WasmネイティブないしWasmプリミティブ
  - GC
  - SIMD
  - Threads
  - Memory64
  - Exception
  - どんどん追加されていく他の機能

## 方向性

- DartがWasm主体で開発されていて、最新Wasm GCなどと相性が良いかもしれない => 正解
- 完全にピュアなWasmを吐き出すのは難しいが、DartのラップはあるにせよWasm GCネイティブな世界を構築するのはあり
- Guile Hootが今回の私の目的に相当合致している
- (jvm).tools.analyzerでClojureのコード解析をしている様子がASTパースの際の参考になりそう
  - マクロ展開は気にする
- CPS変換(継続渡しスタイル変換)については一考の余地あり
- Clojureにおいては末尾再帰が必要なシチュエーションでrecurを明示するので、そこでwasmGCの末尾最適化を呼べばいいのかもしれない

## 戦略

- tools.analyzerでClojueに出現しうる仕様を把握する
- ClojureのパーサーをDartで記述する(マクロ展開は先んじて必要だが、後回しでも良いかも)
- Guile Hootの中で用いられているAST => (CPS変換) => wasmGCの流れを理解する
- 小さな最適化wasmGCコンポーネントをDartでたくさん実装する
- それらの組み合わせで機能を実現できないか考える

## 考慮点

- C言語ですべての機能を作れるか？: 現実的にはかなり困難
- すでにデータ構造やメソッドで用意されているものがあり、wasmへの変換が確立されているのであればそれを使わないと難しい
- しかし、高速性は損ないたくない。メモリ上の表現や最適化などについてまだ理解が浅い

## Guile Hoot

- Schemeコード => Guile CPS Soupの中間表現 => WebAssembly直接生成
  - 中間表現にする際に、最適化の恩恵を受ける

## Jank

<https://github.com/jank-lang/jank/tree/main>

- JankはClojureをCpp+LLVMで実装したもの
- 進捗状況の可視化としてもかなりいい感じ
- よくまとまって読みやすい

## tools.analyzer

- <https://github.com/clojure/tools.analyzer>

## jvm.tools.analyzer

- <https://github.com/clojure/jvm.tools.analyzer>

## ほしい機能

- インタプリタ的な実行
- wasmへの変換と実行
- wasmGCと末尾再起最適化のネイティブな利用
- コンパイルするなら、必要なモジュールだけをロードしてバイナリサイズを小さくする
- JavaScriptを経由せずとも入出力ができるようにする(WASI)
- wasmコンポーネントとの相互運用ができるようにする
- REPL
- ソースマップ
- 詳しく人間に優しいエラーメッセージ
