# Markdownから組版オブジェクトへのパース

require 'redcarpet'
require 'ox'

require_relative 'setting'

require_relative 'typeset_document'
require_relative 'typeset_margin'
require_relative 'typeset_padding'
require_relative 'typeset_font'

require_relative 'dom_handler'
require_relative 'page_style'
require_relative 'page_handler'
require_relative 'block_node_style'
require_relative 'block_node_handler'
require_relative 'inline_node_style'
require_relative 'inline_node_handler'
require_relative 'image_node_handler'
require_relative 'text_handler'

class MarkdownParser

  def initialize(style, fonts)
    @style = style
    @fonts = fonts
  end

  def parse(markdown)
    document = create_typeset_document

    html = markdown_to_html(markdown)
    dom = html_to_dom(html)

    dom_handler = setup_dom_handler()
    dom_handler.create_new_page(document) # 1ページ作っておく
    dom_handler.handle_dom(dom, document)

    document
  end

  private

  def default_sfnt_font
    default_font_name = @style.document.default_font_name
    @fonts[default_font_name].sfnt_font
  end

  def default_font_size
    @style.document.default_font_size
  end

  def default_line_gap
    @style.document.default_line_gap
  end

  def default_margin
    TypesetMargin.zero_margin
  end

  def default_padding
    TypesetPadding.zero_padding
  end

  def get_sfnt_font(tag)
    font_name = if @style.blocks.has_key?(tag)
                  @style.blocks[tag].font_name
                elsif @style.inlines.has_key?(tag)
                  @style.inlines[tag].font_name
                else
                  Setting::Style::DEFAULT
                end

    if font_name != Setting::Style::DEFAULT
      @fonts[font_name].sfnt_font
    else
      default_sfnt_font
    end
  end

  def get_font_size(tag)
    # 今のところフォントサイズはblockでのみ指定可能
    font_size = @style.blocks[tag].font_size
    if font_size == Setting::Style::DEFAULT
      font_size = default_font_size
    end
    font_size
  end

  def get_line_gap(tag)
    line_gap = @style.blocks[tag].line_gap
    if line_gap == Setting::Style::DEFAULT
      line_gap = default_line_gap
    end
    line_gap
  end

  def get_margin(tag)
    margin = @style.blocks[tag].margin
    if margin == Setting::Style::DEFAULT
      margin = default_margin
    end
    margin
  end

  def get_padding(tag)
    padding = @style.blocks[tag].padding
    if padding == Setting::Style::DEFAULT
      padding = default_padding
    end
    padding
  end

  def create_typeset_document
    document = TypesetDocument.new(@style.document.width, @style.document.height)
    document.add_font(default_sfnt_font)
    @style.blocks.each_key do |tag|
      document.add_font(get_sfnt_font(tag))
    end
    @style.inlines.each_key do |tag|
      document.add_font(get_sfnt_font(tag))
    end
    document
  end

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
    dom_handler = DomHandler.new(default_sfnt_font, default_font_size)

    # ページ
    style = get_page_style
    PageHandler.add_to(dom_handler, style)

    # ブロック
    @style.blocks.each do |tag, block|
      style = get_block_node_style(tag, block)
      BlockNodeHandler.add_to(dom_handler, tag, style)
    end

    # インライン
    @style.inlines.each do |tag, inline|
      style = get_inline_node_style(tag, inline)
      InlineNodeHandler.add_to(dom_handler, tag, style)
    end

    # 画像
    ImageNodeHandler.add_to(dom_handler)

    # テキスト
    TextHandler.add_to(dom_handler)

    dom_handler
  end

  def get_page_style
    style = PageStyle.new
    if @style.page.margin != Setting::Style::DEFAULT
      style.margin = @style.page.margin
    else
      style.margin = default_margin
    end
    if @style.page.padding != Setting::Style::DEFAULT
      style.padding = @style.page.padding
    else
      style.padding = default_margin
    end
    style.to_footer_gap = @style.page.to_footer_gap
    style.footer_sfnt_font = default_sfnt_font
    style.footer_font_size = default_font_size
    style
  end

  def get_block_node_style(tag, block)
    style = BlockNodeStyle.new
    style.sfnt_font = get_sfnt_font(tag)
    style.font_size = get_font_size(tag)
    style.line_gap = get_line_gap(tag)
    style.margin = get_margin(tag)
    style.padding = get_padding(tag)
    style.begin_new_page = block.begin_new_page
    style.indent = block.indent
    style
  end

  def get_inline_node_style(tag, inline)
    style = InlineNodeStyle.new
    style.sfnt_font = get_sfnt_font(tag)
    style.ignore_line_feed = inline.ignore_line_feed
    style
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

  parser = MarkdownParser.new(setting.styles["normal"], setting.fonts)
  typeset_document = parser.parse(markdown)
  pdf_document = typeset_document.to_pdf_document

  writer = PdfWriter.new(setting.targets["parse_sample"].output)
  writer.write(pdf_document)
end
