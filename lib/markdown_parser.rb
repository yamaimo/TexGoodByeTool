# Markdownから組版オブジェクトへのパース

require 'redcarpet'
require 'ox'

require_relative 'typeset_document'
require_relative 'typeset_margin'
require_relative 'typeset_padding'
require_relative 'typeset_font'

class MarkdownParser

  HANGING_CHARS = ")]}>,.;:!?）」』、。；：！？ぁぃぅぇぉっゃゅょァィゥェォッャュョ"

  def initialize(width, height, default_sfnt_font, default_font_size, default_line_gap)
    @width = width
    @height = height

    @default_sfnt_font = default_sfnt_font
    @default_font_size = default_font_size
    @default_line_gap = default_line_gap
    @default_margin = TypesetMargin.new
    @default_padding = TypesetPadding.new

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
    dom.each do |node|
      handle_node(node, document)
    end

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
    document.new_page(@page_margin, @page_padding, @to_footer_gap)  # 1ページ作っておく
    add_page_number(document)
    document.add_font(@default_sfnt_font)
    @sfnt_font.each do |tag, font|
      document.add_font(font)
    end
    document
  end

  def handle_node(node, document)
    if node.is_a?(Ox::Node)
      case node.value
      when /^h[1-6]$/
        handle_header(node, document)
      when "p"
        handle_paragraph(node, document)
      when "pre"
        handle_preformatted(node, document)
      when "em"
        handle_emphasis(node, document)
      when "strong"
        handle_strong(node, document)
      when "code"
        handle_code(node, document)
      else
        handle_unknown("<#{node.value}>")
      end
    elsif node.is_a?(String)
      handle_string(node, document)
    else
      handle_unknown(node)
    end
  end

  def handle_header(header, document)
    if (header.value == "h1") && (! document.current_page.empty?)
      document.new_page(@page_margin, @page_padding, @to_footer_gap)
      add_page_number(document)
    end

    sfnt_font = self.get_sfnt_font(header.value)
    font_size = self.get_font_size(header.value)
    line_gap = self.get_line_gap(header.value)
    margin = self.get_margin(header.value)
    padding = self.get_padding(header.value)

    box = document.current_page.new_box(margin, padding, line_gap)
    line = box.new_line
    font = TypesetFont.new(sfnt_font, font_size)
    line.push font.get_font_set_operation

    @typeset_font_stack.push font
    header.each do |child|
      handle_node(child, document)
    end
    @typeset_font_stack.pop
  end

  def handle_paragraph(paragraph, document)
    sfnt_font = self.get_sfnt_font(paragraph.value)
    font_size = self.get_font_size(paragraph.value)
    line_gap = self.get_line_gap(paragraph.value)
    margin = self.get_margin(paragraph.value)
    padding = self.get_padding(paragraph.value)

    box = document.current_page.new_box(margin, padding, line_gap)
    line = box.new_line
    font = TypesetFont.new(sfnt_font, font_size)
    line.push font.get_font_set_operation
    line.push font.get_space(1) # 行頭インデント

    @typeset_font_stack.push font
    paragraph.each do |child|
      handle_node(child, document)
    end
    @typeset_font_stack.pop
  end

  def handle_preformatted(preformatted, document)
    sfnt_font = self.get_sfnt_font(preformatted.value)
    font_size = self.get_font_size(preformatted.value)
    line_gap = self.get_line_gap(preformatted.value)
    margin = self.get_margin(preformatted.value)
    padding = self.get_padding(preformatted.value)

    box = document.current_page.new_box(margin, padding, line_gap)
    line = box.new_line
    font = TypesetFont.new(sfnt_font, font_size)
    line.push font.get_font_set_operation

    @typeset_font_stack.push font
    preformatted.each do |child|
      handle_node(child, document)
    end
    @typeset_font_stack.pop
  end

  def handle_emphasis(emphasis, document)
    sfnt_font = self.get_sfnt_font(emphasis.value)

    line = document.current_page.current_box.current_line
    prev_font = @typeset_font_stack[-1]
    font = TypesetFont.new(sfnt_font, prev_font.size)
    line.push font.get_font_set_operation

    @typeset_font_stack.push font
    emphasis.each do |string|
      # emphasisの下はstringのみ
      handle_string(string, document)
    end
    @typeset_font_stack.pop

    line = document.current_page.current_box.current_line
    line.push prev_font.get_font_set_operation
  end

  def handle_strong(strong, document)
    sfnt_font = self.get_sfnt_font(strong.value)

    line = document.current_page.current_box.current_line
    prev_font = @typeset_font_stack[-1]
    font = TypesetFont.new(sfnt_font, prev_font.size)
    line.push font.get_font_set_operation

    @typeset_font_stack.push font
    strong.each do |string|
      # strongの下はstringのみ
      handle_string(string, document)
    end
    @typeset_font_stack.pop

    line = document.current_page.current_box.current_line
    line.push prev_font.get_font_set_operation
  end

  def handle_code(code, document)
    sfnt_font = self.get_sfnt_font(code.value)

    line = document.current_page.current_box.current_line
    prev_font = @typeset_font_stack[-1]
    font = TypesetFont.new(sfnt_font, prev_font.size)
    line.push font.get_font_set_operation

    @typeset_font_stack.push font
    code.each do |string|
      # codeの下はstringのみ
      # また、改行コードではちゃんと改行する
      handle_string(string, document, ignore_line_feed: false)
    end
    @typeset_font_stack.pop

    line = document.current_page.current_box.current_line
    line.push prev_font.get_font_set_operation
  end

  def handle_string(string, document, ignore_line_feed: true)
    font = @typeset_font_stack[-1]
    string.each_char do |char|
      if (char == "\n") && ignore_line_feed
        next
      end

      page = document.current_page
      box = page.current_box
      line = box.current_line

      if char != "\n"
        line.push font.get_typeset_char(char)
      else
        if line.height == 0
          # 高さを確保しておく
          line.push font.get_strut
        end
        line = box.new_line
        line.push font.get_font_set_operation
      end

      # 改行処理
      if line.width > line.allocated_width
        last_char = line.pop
        if HANGING_CHARS.include?(last_char.to_s)
          # 元に戻して改行しない
          # FIXME: 複数文字続く場合、はみ出しが大きくなる
          line.push last_char
        else
          new_line = document.current_page.current_box.new_line
          new_line.push font.get_font_set_operation
          new_line.push last_char
        end
      end

      # 改ページ処理
      if box.height > box.allocated_height
        last_line = box.pop
        new_page = document.new_page(@page_margin, @page_padding, @to_footer_gap)
        add_page_number(document)
        new_box = new_page.new_box(box.margin, box.padding, box.line_gap)
        new_line = new_box.new_line
        while char = last_line.shift
          new_line.push char
        end
      end
    end
    # FIXME: rescue_font対応はまだ
    # FIXME: 禁則処理とか
    # FIXME: "「"で始まる場合は2分空きにしたり
  end

  def handle_unknown(string)
    puts "[unknown] #{string}"
  end

  def add_page_number(document)
    page_number = document.page_count
    is_odd_page = page_number % 2 == 1
    page_number_str = page_number.to_s

    footer = document.current_page.footer
    line = footer.new_line
    font = TypesetFont.new(@default_sfnt_font, @default_font_size)
    # 右揃えできるように、フォント設定は最後に左端に追加する

    page_number_str.each_char do |char|
      line.push font.get_typeset_char(char)
    end

    if is_odd_page
      space = line.allocated_width - line.width
      space_as_char_count = space / @default_font_size
      line.unshift font.get_space(space_as_char_count)
    end
    line.unshift font.get_font_set_operation
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
