TeXグッバイしたいツール
=======================

『TeXグッバイしたい本』の組版に使用しているツール。

以下、自分用のメモ：

準備
----

以下のgemを使ってるので、必要ならインストールしておく。

```
$ gem install redcarpet ox
```

原稿を書くリポジトリから`git submodule add`する。

```
# 原稿のあるディレクトリへ
$ cd path/to/script/

# tool/というディレクトリに持ってくるとする
$ git submodule add git@github.com:yamaimo/TexGoodByeTool.git tool
```

`Rakefile.sample`をコピーして編集。

```
$ cd ..
$ cp tool/Rakefile.samaple Rakefile
$ vi Rakefile
```

原稿のリポジトリで差分をコミットしておく。

原稿のタイプセット
------------------

`rake`でタイプセット。

そのままPDFを開きたい場合は`rake open`。

PDFを削除したい場合は`rake clean`。

ツールの更新/同期
-----------------

ツールを修正する場合、tool/ディレクトリで変更してツールのリポジトリへコミットすればいい。

原稿で使用するツールを特定のコミットにしたい場合、
tool/ディレクトリでツールのリポジトリから使いたいコミットをチェックアウトし、
原稿のリポジトリで差分（参照するコミットの変更）をコミットすればいい。

原稿のリポジトリで参照しているコミットとtool/のコミットがズレてるとき、
原稿のリポジトリで`git submodule update`をすれば、
原稿のリポジトリが参照しているコミットの内容になる。
