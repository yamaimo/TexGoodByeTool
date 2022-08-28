# 組版オブジェクト：本文領域

require_relative 'block_style'
require_relative 'typeset_block'
require_relative 'typeset_line'

class TypesetBody
  # 子としてTypesetBlock, TypesetLineを持ち、
  # これらに#width, #height, #margin, #write_to(content)を要求する。
  # 親はTypesetPageで、これに#break_pageを要求する。

  def initialize(parent, text_style, line_gap, allocated_width, allocated_height)
    @parent = parent
    @block_style = BlockStyle.new(line_gap: line_gap)
    @text_style = text_style
    @allocated_width = allocated_width
    @allocated_height = allocated_height
    @children = []
    @next = nil
  end

  attr_reader :block_style, :text_style, :allocated_width, :allocated_height

  def width
    # FIXME: 自身のpadding, 子の間のmarginの計算が必要だけど後回し
    @children.map(&:width).max
  end

  def height
    # FIXME: 自身のpadding, 子の間のmarginの計算が必要だけど後回し
    # FIXME: 子が行なのかブロックなのかで行送りの計算が必要
    @children.map(&:height).sum
  end

  def new_block(block_style, text_style)
    allocated_width = @allocated_width
    # FIXME: さらに自身のpadding, 子のmarginから幅を計算する必要があるが後回し
    allocated_height = @allocated_height - self.height
    # FIXME: さらに自身のpadding, 子のmarginから高さを計算する必要があるが後回し
    child = TypesetBlock.new(self, block_style, text_style, allocated_width, allocated_height)
    @children.push child
    child
  end

  def new_line
    allocated_width = @allocated_width
    # FIXME: さらに自身のpadding, 子のmarginから幅を計算する必要があるが後回し
    child = TypesetLine.new(self, allocated_width)
    @children.push child
    child
  end

  # 改ページ用
  def push_line(line)
    @children.push line
  end

  def break_line
    # 改ページが必要になってる場合、改ページして新しい行を返す
    # そうでない場合、単に新しい行を返す
    if self.height > @allocated_height
      self.break_page
      @next.new_line
    else
      self.new_line
    end
  end

  def break_page
    @next = @parent.break_page

    # FIXME: 最後の子要素が空なら取り除くとか必要かも

    last_child = @children.last
    case last_child
    when TypesetBlock
      @next.new_block(last_child.block_style, last_child.text_style)
    when TypesetLine
      last_line = @children.pop
      @next.push_line last_line
    end
  end

  def write_to(content)
    # FIXME: 自身の境界線を引いたりpaddingスキップしたりが必要だけど後回し
    y = 0
    @children.each do |child|
      content.stack_graphic_state do
        child_x = 0 # FIXME: paddingとかmarginの計算が必要だけど後回し
        content.move_origin child_x, y
        child.write_to(content)
        # この間のline_gap, marginの計算も必要だけど後回し
        y += child.height
      end
    end
  end

end

if __FILE__ == $0
  require_relative 'sfnt_font'
  require_relative 'length_extension'
  require_relative 'pdf_document'
  require_relative 'pdf_font'
  require_relative 'pdf_page'
  require_relative 'pdf_text'
  require_relative 'pdf_object_binder'
  require_relative 'block_style'

  class TypesetPageMock
    def initialize(parent)
      @parent = parent
      @body = nil
    end

    attr_accessor :body

    def break_page
      new_page = TypesetPageMock.new(@parent)
      @parent.push new_page

      new_body = TypesetBody.new(new_page, @body.text_style, @body.block_style.line_gap,
                                 @body.allocated_width, @body.allocated_height)
      new_page.body = new_body

      new_body
    end

    def write_to(content)
      @body.write_to(content)
    end
  end

  using LengthExtension

  sfnt_font = SfntFont.load('ipaexm.ttf')
  pdf_font = PdfFont.new(sfnt_font)
  font_size = 14

  text_style = TextStyle.new(font: pdf_font, size: font_size, verbatim: false)

  pages = []
  page = TypesetPageMock.new(pages)
  pages.push page

  body = TypesetBody.new(page, text_style, 4.pt, 5.cm, 5.cm)
  page.body = body

  line = body.new_line

  script = <<~END_OF_SCRIPT
    二人の若い紳士が、すっかりイギリスの兵隊のかたちをして、
    ぴかぴかする鉄砲をかついで、歩いておりました。
    Two young gentlemen were walking along,
    fully dressed as British soldiers, carrying shiny guns.
  END_OF_SCRIPT

  text = line.new_text
  script.each_char do |char|
    text.add_char(char)
    text = text.latest
  end

  # A5
  page_width = 148.mm
  page_height = 210.mm
  document = PdfDocument.new(page_width, page_height)

  pdf_pages = []
  pages.each do |page|
    pdf_page = PdfPage.add_to(document)
    pdf_pages.push pdf_page
    pdf_page.add_content do |content|
      page.write_to(content)
    end
  end

  binder = PdfObjectBinder.new
  # pageの内容だけ見る
  pdf_pages.each do |pdf_page|
    pdf_page.attach_to(binder)
  end

  binder.serialized_objects.each do |serialized_object|
    puts serialized_object
  end
end
