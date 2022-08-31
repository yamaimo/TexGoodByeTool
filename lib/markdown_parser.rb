# Markdownから組版オブジェクトへのパース

require 'redcarpet'
require 'ox'

require_relative 'setting'

require_relative 'typeset_document'
require_relative 'page_style'
require_relative 'block_style'
require_relative 'inline_style'
require_relative 'text_style'

require_relative 'dom_handler'
require_relative 'block_node_handler'
require_relative 'inline_node_handler'
#require_relative 'image_node_handler'
require_relative 'text_handler'

class MarkdownParser

  def initialize(style_setting, font_settings)
    @style_setting = style_setting
    @font_settings = font_settings
  end

  def parse(markdown)
    html = markdown_to_html(markdown)
    dom = html_to_dom(html)

    dom_handler = setup_dom_handler
    document, body = create_typeset_document_and_body
    dom_handler.handle_dom(dom, body, document)

    document
  end

  private

  def markdown_to_html(markdown)
    redcarpet = Redcarpet::Markdown.new(Redcarpet::Render::HTML, fenced_code_blocks: true)
    html = redcarpet.render markdown
    "<body>#{html}</body>"
  end

  def html_to_dom(html)
    dom = Ox.load(
      html,
      skip: :skip_none,   # 改行や空白をスキップしない
      effort: :tolerant)  # 閉じタグがなくてもOKにする
  end

  def setup_dom_handler
    dom_handler = DomHandler.new

    # ブロック
    @style_setting.blocks.each do |tag, block_setting|
      block_style = get_block_style(block_setting)
      text_style = get_text_style(block_setting)
      BlockNodeHandler.add_to(dom_handler, tag, block_style, text_style)
    end

    # インライン
    @style_setting.inlines.each do |tag, inline_setting|
      inline_style = get_inline_style(inline_setting)
      text_style = get_text_style(inline_setting)
      InlineNodeHandler.add_to(dom_handler, tag, inline_style, text_style)
    end

    # 画像
    #ImageNodeHandler.add_to(dom_handler)

    # テキスト
    TextHandler.add_to(dom_handler)

    dom_handler
  end

  def create_typeset_document_and_body
    document_setting = @style_setting.document
    document = TypesetDocument.new(document_setting.width, document_setting.height)

    page_style = get_page_style
    page = document.new_page(page_style)

    default_text_style = get_default_text_style
    body = page.new_body(default_text_style, document_setting.default_line_gap)

    [document, body]
  end

  def get_page_style
    page_setting = @style_setting.page
    args = {}
    args[:margin] = page_setting.margin if page_setting.margin != Setting::Style::DEFAULT
    args[:padding] = page_setting.padding if page_setting.padding != Setting::Style::DEFAULT
    args[:to_footer_gap] = page_setting.to_footer_gap
    PageStyle.new(**args)
  end

  def get_default_text_style
    document_setting = @style_setting.document
    font = @font_settings[document_setting.default_font_name].pdf_font
    size = document_setting.default_font_size
    TextStyle.new(font: font, size: size, verbatim: false)
  end

  def get_block_style(block_setting)
    args = {}
    args[:margin] = block_setting.margin if block_setting.margin != Setting::Style::DEFAULT
    args[:padding] = block_setting.padding if block_setting.padding != Setting::Style::DEFAULT
    args[:line_gap] = block_setting.line_gap if block_setting.line_gap != Setting::Style::DEFAULT
    args[:begin_new_page] = block_setting.begin_new_page
    args[:indent] = block_setting.indent
    BlockStyle.new(**args)
  end

  def get_inline_style(inline_setting)
    args = {}
    args[:margin] = inline_setting.margin if inline_setting.margin != Setting::Style::DEFAULT
    args[:padding] = inline_setting.padding if inline_setting.padding != Setting::Style::DEFAULT
    InlineStyle.new(**args)
  end

  def get_text_style(node_setting)
    args = {}
    if node_setting.font_name != Setting::Style::DEFAULT
      args[:font] = @font_settings[node_setting.font_name].pdf_font
    end
    args[:size] = node_setting.font_size if node_setting.font_size != Setting::Style::DEFAULT
    args[:verbatim] = node_setting.verbatim if node_setting.verbatim != Setting::Style::DEFAULT
    TextStyle.new(**args)
  end

end

if __FILE__ == $0
  require_relative 'length_extension'
  require_relative 'setting_dsl'
  require_relative 'pdf_writer'

  using LengthExtension

  markdown = <<~END_OF_MARKDOWN
    # 1章 ほげほげ

    # 2章 ふがふが

    あれが*こうなって*そう。
    **強調**もやる。

    コードは`test`みたいになる。

    ```
    # Rubyのコードの例

    class Dummy

      def initialize(name)
        @name = name
      end

    end
    ```

    HTMLも。

    ```
    <html>
      <body>
        test
      </body>
    </html>
    ```

    ## 1節 あばばば

    そしてこうなる。

    おわり。

    #{File.read "sample.md"}
  END_OF_MARKDOWN

  setting_str = <<~END_OF_SETTING
    target "parse_sample" do
      output "parse_sample.pdf"
      sources "hoge.md"
      style "normal"
    end

    default_target "parse_sample"

    style "normal" do
      document do
        paper width: 148.mm, height: 210.mm
        default_font name: "ipa_mincho", size: 10.pt
        default_line_gap (10.pt / 2)
      end

      page do
        margin top: 1.cm, right: 1.cm, bottom: 1.5.cm, left: 1.cm
      end

      block "h1" do
        margin bottom: 14.pt
        font name: "ipa_gothic", size: 14.pt
      end

      block "h2" do
        margin top: 10.pt, bottom: 7.pt
        font name: "ipa_gothic", size: 12.pt
      end

      block "p" do
        margin top: 7.pt, bottom: 7.pt
      end

      block "pre" do
        margin top: 15.pt, bottom: 15.pt
        line_gap 2.pt
      end

      inline "em" do
        font name: "ipa_gothic"
      end

      inline "strong" do
        font name: "ipa_gothic"
      end

      inline "code" do
        font name: "ricty"
      end
    end

    font "ipa_mincho" do
      file "ipaexm.ttf"
    end

    font "ipa_gothic" do
      file "ipaexg.ttf"
    end

    font "ricty" do
      file "RictyDiminished-Regular.ttf"
    end
  END_OF_SETTING

  setting = SettingDsl.read(setting_str)

  parser = MarkdownParser.new(setting.styles[:normal], setting.fonts)
  typeset_document = parser.parse(markdown)
  pdf_document = typeset_document.to_pdf_document

  writer = PdfWriter.new(setting.targets[:parse_sample].output)
  writer.write(pdf_document)
end
