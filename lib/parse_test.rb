# erbとredcarpetとoxのテスト

require 'erb'
require 'redcarpet'
require 'ox'

def erb_test
  "erbによる出力"
end

# あとで評価したいコードは独自タグでruby_code要素としておくとよさそう
# ただし、``で囲っておかないとmarkdownとして解釈されてしまう場合がある
# ruby_code要素の下に一段code要素が挟まるので注意

def lazy_eval_wrong(str)
  "<ruby_code>#{str}</ruby_code>"
end

def lazy_eval(str)
  "<ruby_code>`#{str}`</ruby_code>"
end

markdown = <<~END_OF_MARKDOWN
  # テスト
  
  Markdownのテスト。

  ## 強調など
  
  テキストの途中で*やや強調*や**すごく強調**があった場合にどうなるのか、
  あと、改行の扱いを確認する。
  それと`code`も。

  ![雪だるま](christmas_snowman.png)

  ```
  # Rubyのコードの例

  class Dummy

    def initialize(name)
      @name = name
    end

  end
  ```

  `<pre>`内のHTMLがパースされないかも。

  ```
  <html>
    <body>
      test
    </body>
  </html>
  ```

  <%= erb_test %>をやってみる。
  <%=
    lazy_eval_wrong <<~END_OF_CODE.chomp
      hoge << "a"
      puts <<~END_OF_STR
        ほげほげ
        ふがふが
      END_OF_STR
    END_OF_CODE
  %>
  <%= lazy_eval_wrong "15*10*4" %>
  <%=
    lazy_eval <<~END_OF_CODE.chomp
      hoge << "a"
      puts <<~END_OF_STR
        ほげほげ
        ふがふが
      END_OF_STR
    END_OF_CODE
  %>
  <%= lazy_eval "15*10*4" %>
END_OF_MARKDOWN

puts "==== markdown (before erb) ==="
puts markdown
puts "=============================="

# markdown (before erb) -> markdown (after erb)

markdown = ERB.new(markdown).result

puts "==== markdown (after erb) ===="
puts markdown
puts "=============================="

# markdown -> html

redcarpet = Redcarpet::Markdown.new(Redcarpet::Render::HTML, fenced_code_blocks: true)
html = redcarpet.render markdown

puts "==== html ===================="
puts html
puts "=============================="

# html -> dom

# メモ1
# Ox.parseは最後の要素を返すっぽい。
# なので、そのままだと最後の段落を返す。
# <body>...</body>で囲うことで全体が変えるようになる。

# メモ2
# 継承関係は
# Ox::Document < Ox::Element < Ox::Node
# Nodeは#valueをもつ
# Elementは#eachや#nodesをもち、ツリーを作れる
# Documentは#rootでルートのElementを返す
# また、ElementはOx::HasAttrsをincludeしていて、
# #[]で属性にアクセスしたり#attributesで属性と値のHashを取得できる

# メモ3
# リーフになる文字列はNodeではなくStringになっていた。
# また、nodesではclassがElementである子要素だけではなく、すべて入っていた。

# メモ4
# Ox.parseはオプションを渡せない（Ox.default_options=で指定する手はある）
# Ox.loadならオプションを渡せるので、こっちを使うと良さそう
# skip: :skip_noneはブロック内の改行や空白をそのままにしてくれる
# skip: :skip_offだとブロック間の改行や空白もそのままにするので、都合悪い
#
# メモ5
# <img>タグが綴じられてなかったのでxmlとしてエラーが発生した。
# Ox.loadでオプションとしてeffort: :tolerantを指定したらOKになった。

html_body = "<body>#{html}</body>"
dom = Ox.load(
  html_body,
  skip: :skip_none,   # 改行や空白をスキップしない
  effort: :tolerant)  # 閉じタグがなくてもOKにする

def render_node(node, level)
  indent = " " * level
  if node.is_a?(Ox::Element)
    puts "#{indent}<#{node.value}> (Element, nodes.size=#{node.nodes.size})"
    node.each do |child|
      render_node(child, level+2)
    end
  elsif node.is_a?(Ox::Node)
    puts "#{indent}<#{node.value}> (Node)"
  else
    node_enc = node.force_encoding(Encoding.default_external)
    node_enc_ws = node_enc.gsub(" ", "[空白]")
    node_enc_ws_br = node_enc_ws.gsub("\n", "[改行]")
    puts "#{indent}#{node_enc_ws_br} (#{node.class})"
  end
end

puts "==== dom ====================="
render_node(dom, 0)
puts "=============================="
