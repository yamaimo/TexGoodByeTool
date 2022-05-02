# Markdownから組版オブジェクトへのパース

require 'redcarpet'
require 'ox'

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
require_relative 'text_handler'

class MarkdownParser

  def initialize(width, height, default_sfnt_font, default_font_size, default_line_gap)
    @width = width
    @height = height

    @default_sfnt_font = default_sfnt_font
    @default_font_size = default_font_size
    @default_line_gap = default_line_gap
    @default_margin = TypesetMargin.zero_margin
    @default_padding = TypesetPadding.zero_padding

    @page_margin = @default_margin
    @page_padding = @default_padding
    @to_footer_gap = 0

    @sfnt_font = {}
    @font_size = {}
    @line_gap = {}
    @margin = {}
    @padding = {}

    @typeset_font_stack = []
  end

  attr_accessor :width, :height
  attr_accessor :default_sfnt_font, :default_font_size, :default_line_gap
  attr_accessor :default_margin, :default_padding
  attr_accessor :page_margin, :page_padding, :to_footer_gap

  def set_sfnt_font(tag, sfnt_font)
    @sfnt_font[tag] = sfnt_font
  end

  def set_font_size(tag, font_size)
    @font_size[tag] = font_size
  end

  def set_line_gap(tag, line_gap)
    @line_gap[tag] = line_gap
  end

  def set_margin(tag, margin)
    @margin[tag] = margin
  end

  def set_padding(tag, padding)
    @padding[tag] = padding
  end

  def get_sfnt_font(tag)
    @sfnt_font[tag] || @default_sfnt_font
  end

  def get_font_size(tag)
    @font_size[tag] || @default_font_size
  end

  def get_line_gap(tag)
    @line_gap[tag] || @default_line_gap
  end

  def get_margin(tag)
    @margin[tag] || @default_margin
  end

  def get_padding(tag)
    @padding[tag] || @default_padding
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

  def markdown_to_html(markdown)
    redcarpet = Redcarpet::Markdown.new(Redcarpet::Render::HTML, fenced_code_blocks: true)
    html = redcarpet.render markdown
    "<body>#{html}</body>"
  end

  def html_to_dom(html)
    dom = Ox.load(html, skip: :skip_none)  # 改行や空白をスキップしない
  end

  def create_typeset_document
    document = TypesetDocument.new(@width, @height)
    document.add_font(@default_sfnt_font)
    @sfnt_font.each do |tag, font|
      document.add_font(font)
    end
    document
  end

  def setup_dom_handler
    dom_handler = DomHandler.new(@default_sfnt_font, @default_font_size)

    # ページ
    style = get_page_style
    PageHandler.add_to(dom_handler, style)

    # header
    (1..6).each do |level|
      tag = "h#{level}"
      style = get_block_node_style(tag)
      if level == 1
        style.begin_new_page = true
      end
      BlockNodeHandler.add_to(dom_handler, tag, style)
    end

    # paragraph
    tag = "p"
    style = get_block_node_style(tag)
    style.indent = 1
    BlockNodeHandler.add_to(dom_handler, tag, style)

    # preformatted
    tag = "pre"
    style = get_block_node_style(tag)
    BlockNodeHandler.add_to(dom_handler, tag, style)

    # emphasis
    tag = "em"
    style = get_inline_node_style(tag)
    InlineNodeHandler.add_to(dom_handler, tag, style)

    # strong
    tag = "strong"
    style = get_inline_node_style(tag)
    InlineNodeHandler.add_to(dom_handler, tag, style)

    # code
    tag = "code"
    style = get_inline_node_style(tag)
    style.ignore_line_feed = false
    InlineNodeHandler.add_to(dom_handler, tag, style)

    # テキスト
    TextHandler.add_to(dom_handler)

    dom_handler
  end

  def get_page_style
    style = PageStyle.new
    style.margin = @page_margin
    style.padding = @page_padding
    style.to_footer_gap = @to_footer_gap
    style.footer_sfnt_font = @default_sfnt_font
    style.footer_font_size = @default_font_size
    style
  end

  def get_block_node_style(tag)
    style = BlockNodeStyle.new
    style.sfnt_font = get_sfnt_font(tag)
    style.font_size = get_font_size(tag)
    style.line_gap = get_line_gap(tag)
    style.margin = get_margin(tag)
    style.padding = get_padding(tag)
    style
  end

  def get_inline_node_style(tag)
    style = InlineNodeStyle.new
    style.sfnt_font = get_sfnt_font(tag)
    style
  end

end

if __FILE__ == $0
  require_relative 'length_extension'
  require_relative 'sfnt_font'
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

  # A5
  page_width = 148.mm
  page_height = 210.mm

  # IPA明朝
  ipa_mincho = SfntFont.load('ipaexm.ttf')

  # IPAゴシック
  ipa_gothic = SfntFont.load('ipaexg.ttf')

  # Ricty, 10pt
  ricty = SfntFont.load('RictyDiminished-Regular.ttf')

  # フォントは10pt
  font_size = 10.pt
  line_gap = font_size / 2

  parser = MarkdownParser.new(page_width, page_height, ipa_mincho, font_size, line_gap)

  parser.page_margin = TypesetMargin.new(top: 1.cm, right: 1.cm, bottom: 1.cm, left: 1.cm)
  parser.set_margin("h1", TypesetMargin.new(bottom: 14.pt))
  parser.set_sfnt_font("h1", ipa_gothic)
  parser.set_font_size("h1", 14.pt)
  parser.set_margin("h2", TypesetMargin.new(top: 10.pt, bottom: 7.pt))
  parser.set_sfnt_font("h2", ipa_gothic)
  parser.set_font_size("h2", 12.pt)
  parser.set_margin("p", TypesetMargin.new(top: 7.pt, bottom: 7.pt))
  parser.set_margin("pre", TypesetMargin.new(top: 15.pt, bottom: 15.pt))
  parser.set_line_gap("pre", 2.pt)
  parser.set_sfnt_font("em", ipa_gothic)
  parser.set_sfnt_font("strong", ipa_gothic)
  parser.set_sfnt_font("code", ricty)

  typeset_document = parser.parse(markdown)
  pdf_document = typeset_document.to_pdf_document

  writer = PdfWriter.new("parse_sample.pdf")
  writer.write(pdf_document)
end
