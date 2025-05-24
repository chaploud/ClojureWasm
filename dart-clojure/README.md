# Dart Clojure

Dartで実装するClojure処理系

## ディレクトリ解説

```sh
.
├── CHANGELOG.md # 変更履歴
├── README.md # README(本ファイル)
├── analysis_options.yaml # 静的解析の設定
├── pubspec.lock # 依存関係のロック
├── pubspec.yaml # プロジェクト設定・依存関係
├── bin/ # 実行可能ファイル(dart runで実行される)
│   └── dart_clojure.dart # エントリーポイント
├── lib/ # メインライブラリコード
│   ├── src/ # 内部実装（private) 非公開API
│   └── dart_clojure.dart # 公開API(他のパッケージからimport可能)
└── test/ # テストコード
    └── dart_clojure_test.dart # *_test.dart
```
