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

## Guile Hoot

- Schemeコード => Guile CPS Soupの中間表現 => WebAssembly直接生成
  - 中間表現にする際に、最適化の恩恵を受ける
