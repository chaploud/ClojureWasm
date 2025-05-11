# Guile Hoot

Hootは、[Spritely Institute](https://spritely.institute/)によって立ち上げられた[GuileからWebAssemblyへのプロジェクト](https://spritely.institute/news/guile-on-web-assembly-project-underway.html)のコードネームです。Hootには、コンパイラに加えて、WATパーサー、アセンブラ、逆アセンブラ、インタプリタなどを含む完全なWebAssemblyツールチェインが含まれています。

既知の制限事項を含むプロジェクトの現状についての詳細は、[ドキュメントの「Status」セクション](https://spritely.institute/files/docs/guile-hoot/latest/Status.html)をご覧ください。

## プロジェクトの目標とタイムフレーム

Hootは、[R7RS-small Scheme](https://small.r7rs.org/)のすべてをWebAssembly（Wasm）に事前コンパイル（ahead-of-timeコンパイル）することを目指しています。Hootは、末尾呼び出し（tail calls）やガベージコレクション（garbage collection）といったいくつかのWasm拡張機能を利用します。幸いなことに、これらの拡張機能はMozilla FirefoxやGoogle Chromeなどの主要なブラウザで既に利用可能であり、間もなくあらゆる場所で安定版のブラウザリリースに搭載される予定です！

R7RS-smallのサポート完了後、Guile全体のサポートへと進む予定です。私たちは、初期の成果物を構築する際にも、この最終目標を念頭に置いています。

生成されるコードはすべて、標準のGuileで動作するはずです。現在、私たちはGuileにまだリリースされていないいくつかの変更をアップストリームしているため、GitのmainブランチからビルドされたGuileが必要です。

## 現状の姿

最終的には、Schemeプログラムを単一のWebAssemblyファイルにコンパイルできるようになる見込みです。ウェブブラウザにデプロイする際には、関連するJavaScriptモジュールがあります。一部の非ウェブターゲットは、JavaScript実装（例: node）によってホストされており、これらはウェブブラウザと同様です。それ以外の場合、WASIホスト上では、最終的にWASI固有のサポートモジュールを用意する予定です。

最小のコンパイル済みモジュールサイズは、非圧縮で数十キロバイト程度です。JavaScriptとのインピーダンスマッチングを行うための補助的なWebAssemblyモジュールは非圧縮で約4キロバイト、汎用JSライブラリは圧縮されていないJSで約500行です。Schemeの実装を進めるにあたり、コンパイルされたすべてのプログラムにGuileの標準ライブラリ全体が含まれるのではなく、この「小さなプログラムは小さなファイルにコンパイルされる」という特性を維持したいと考えています。

## ところで… なぜ「Hoot」という名前なのですか？

私たちは、このプロジェクトには可愛いプロジェクト名とマスコットが必要だと考えました。当時、フクロウが良いという意見で皆が一致し、ちょうどChristine Lemmer-Webberがこのフクロウのピクセルアートを描き上げたところだったので、それがマスコットになりました。名前はそこから自然に決まりました。

## プロジェクトの更新情報

[ログファイル](https://www.google.com/search?q=design/log.md)をご覧ください。

## Hoot安定版のインストール

なお、この記事の執筆時点では、HootはGuileの開発版を必要とします。あなたがこれを読んでいる時点では、そうではないかもしれません！

以下は、Hootをインストールするためのシステム別の手順です。

### Guixでのインストール

Hootは既に[Guix](https://guix.gnu.org/)で利用可能です：

```
guix shell --pure guile-next guile-hoot
```

### Mac OS (homebrew)でのインストール

Hootは、[Alex Conchillo Flaqué氏のおかげでMac OSで利用可能になりました](https://emacs.ch/@aconchillo/111257400576804393)（ここでは氏の手順を転載しています）！

まだ追加していない場合は、GuileのHomebrew tapを追加します：

```
brew tap aconchillo/guile
```

Guileが既にHomebrewでインストールされている場合は、新しいバージョンが必要なため、リンクを解除します：

```
brew unlink guile
```

これで、Hootをインストールするだけです：

```
brew install guile-hoot
```

これにより、Guileの最先端バージョンである`guile-next`もインストールされるため、bottleが利用できない場合は時間がかかることがあります。

## ソースからのビルド

### 簡単な方法：Guixを使用

Guixが面倒な作業をすべて代行してくれるため、これが圧倒的に簡単な方法です。

まず、リポジトリをクローンします：

```
git clone https://gitlab.com/spritely/guile-hoot
cd guile-hoot
guix shell
./bootstrap.sh && ./configure && make
```

カスタムバージョンのGuileと最先端バージョンのV8を使用しているため、`guix shell`のステップにはビルドに時間がかかります。
すべてが正常に動作すれば、`make check`を実行できます：

```
make check
```

すべてパスしましたか？素晴らしい！これでHootがあなたのマシンで動作することが確認できました！

### 高度な方法：依存関係を自分でビルドする

Hootが実際に何をしているのかをより深く理解したい、あるいはHootで使用されるGuileのバージョンを改造したい、などと考えているかもしれませんね！このセクションはそんなあなたのためのものです。

まず、`main`ブランチからGuileをビルドする必要があります。

その後、このリポジトリをクローンしてビルドできます：

```
git clone https://gitlab.com/spritely/guile-hoot
cd guile-hoot
./bootstrap.sh && ./configure && make
```

本番環境のWasmホストに対してテストスイートを実行するには、最新バージョンのV8、またはNodeJS 22+のようなV8ディストリビューションが必要です。NodeJSが最も簡単な方法です。

V8のビルドは面倒です。`depot_tools`をインストールする必要があります。詳細は [https://v8.dev/docs/source-code](https://v8.dev/docs/source-code) を参照してください。インストール後、ビルドについては [https://v8.dev/docs/build](https://v8.dev/docs/build) を参照してください。これにより、（x86-64プラットフォームの場合）`out/x64.release`に`d8`バイナリが生成されます。

これらがすべてうまくいけば、`make check`を実行できるはずです：

```
make check
```

V8関連の作業をスキップしたい場合は、代わりに私たち自身のWasmインタプリタに対してテストスイートを実行できます：

```
make check WASM_HOST=hoot
```

## 試してみる

Hootは自己完結型のシステムなので、最も簡単な試用方法はGuile REPLからです：

```
./pre-inst-env guile
```

Guileプロンプトから、以下のように入力して、Hootの組み込みWasmインタプリタでプログラム`42`を評価します：

```scheme
scheme@(guile-user)> ,use (hoot reflect)
scheme@(guile-user)> (compile-value 42)
$5 = 42
```

さらに興味深いことに、Wasmゲストモジュール内に存在するScheme手続きは、ホスト手続きであるかのようにSchemeから呼び出すことができます：

```scheme
scheme@(guile-user)> (define hello (compile-value '(lambda (x) (list "hello" x))))
scheme@(guile-user)> hello
$6 = #<hoot #<procedure>>
scheme@(guile-user)> (hello "world")
$7 = #<hoot ("hello" "world")>
```

Hootはまた、CLIやビルドスクリプトを介してSchemeファイルをWasmにコンパイルするために使用できる`guild compile-wasm`サブコマンドも導入しています：

```
echo 42 > 42.scm
./pre-inst-env guild compile-wasm -o 42.wasm 42.scm
```

実際に`42.wasm`をロードするには、前述のHoot VMを使用するか、ウェブブラウザなどの本番環境のWebAssembly実装を使用できます。HootはFirefox 121以降およびChrome 119以降と互換性があります。SafariなどのWebKitベースのブラウザは、Hootが依存するWasm GCおよび末尾呼び出し機能をWebKitがまだ備えていないため、現在互換性がありません。

生成されたWebAssemblyはウェブブラウザやJavaScriptに依存しませんが、BigInt実装など、ホストシステムからいくつかの機能を利用します。ウェブブラウザの場合、これらの機能は[`reflect.js`](https://www.google.com/search?q=./reflect-js/reflect.js)によって提供されます。このリフレクションライブラリには、2つの補助的なWebAssemblyモジュールが必要です：

1) [`reflect.wat`](https://www.google.com/search?q=./reflect-wasm/reflect.wat)からコンパイルされる`reflect.wasm`
2) [`wtf8.wat`](https://www.google.com/search?q=./reflect-wasm/wtf8.wat)からコンパイルされる`wtf8.wasm`。

より詳細なチュートリアルと完全なAPIドキュメントについては、マニュアルをご覧ください！

## 使用例

新しいプロジェクトをすぐに開始するには、プロジェクトテンプレートの使用方法の説明について`examples/project-template/README.md`を参照してください。

Hootの使用例については、私たちの他のリポジトリもいくつか確認してみてください：

* [https://gitlab.com/spritely/guile-hoot-ffi-demo](https://gitlab.com/spritely/guile-hoot-ffi-demo)
* [https://gitlab.com/spritely/guile-hoot-meta-repl](https://gitlab.com/spritely/guile-hoot-meta-repl)
* [https://gitlab.com/spritely/guile-hoot-game-jam-template](https://gitlab.com/spritely/guile-hoot-game-jam-template)

-----

以上が翻訳です。原文の意味を理解し、自然な日本語になるよう努めました。
