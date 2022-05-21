TeXグッバイしたいツール
=======================

『TeXグッバイしたい本』の組版に使用しているツール。

以下、自分用のメモ：

準備
----

以下のgemを使ってるので、必要ならインストールしておく。

```
$ gem install redcarpet ox chunky_png
```

原稿を書くリポジトリから`git submodule add`する。

```
# 原稿のあるディレクトリへ
$ cd path/to/script/

# tool/というディレクトリに持ってくるとする
$ git submodule add git@github.com:yamaimo/TexGoodByeTool.git tool
```

`Rakefile`をコピー。

```
$ cp tool/Rakefile .
```

`setting.rb.sample`をコピーして編集。

```
$ cp tool/setting.rb.samaple setting.rb
$ vi setting.rb
```

`setting.rb`で使えるDSLは`lib/setting_dsl.rb`を参照。

原稿のリポジトリで差分をコミットしておく。

原稿のタイプセット
------------------

`rake`でタイプセット。

そのままPDFを開きたい場合は`rake open`。

PDFを削除したい場合は`rake clean`。

`setting.rb`で設定されたターゲットに対してビルド、オープンもできる。

```
# setting.rbでchap1というターゲットが設定されている場合：
$ rake build[chap1]
$ rake open[chap1]
```

ツールの更新/同期
-----------------

ツールを修正する場合、tool/ディレクトリで変更してツールのリポジトリへコミットすればいい。

原稿で使用するツールを特定のコミットにしたい場合、
tool/ディレクトリでツールのリポジトリから使いたいコミットをチェックアウトし、
原稿のリポジトリで差分（参照するコミットの変更）をコミットすればいい。

原稿のリポジトリで参照しているコミットとtool/のコミットがズレてるとき、
原稿のリポジトリで`git submodule update`をすれば、
原稿のリポジトリが参照しているコミットの内容になる。
