# 組版オブジェクト：行

require_relative 'typeset_margin'
require_relative 'text_style'
require_relative 'typeset_inline'
require_relative 'typeset_text'

class TypesetLine
  # 子としてTypesetInline, TypesetText, TypesetImageを持ち、
  # これらに#width, #ascender, #descender,
  # #stretch_count, #stretch_width=, #write_to(content)を要求する。
  # 親はTypesetBodyもしくはTypesetBlockで、
  # これらに#text_style, #break_lineを要求する。

  # FIXME:
  # 子要素間に伸縮スペースを入れるか設定で必要そう。

  def initialize(parent, allocated_width)
    @parent = parent
    @allocated_width = allocated_width
    @text_style = @parent.text_style
    @allocated_width = allocated_width
    @children = []
    @next = nil
  end

  attr_reader :text_style, :allocated_width

  def width
    # FIXME: 子の間のmarginの計算が必要だけど後回し
    @children.map(&:width).sum
  end

  def height
    self.ascender - self.descender
  end

  def ascender
    # FIXME: 子のmarginの計算も必要だけど後回し
    @children.map(&:ascender).max || 0
  end

  def descender
    # FIXME: 子のmarginの計算も必要だけど後回し
    @children.map(&:descender).min || 0
  end

  def margin
    TypesetMargin.zero
  end

  def stretch_count
    @children.map(&:stretch_count).sum
  end

  def stretch_width=(width)
    @children.each do |child|
      child.stretch_width = width
    end
  end

  def latest
    @next.nil? ? self : @next.latest
  end

  def new_inline(inline_style, text_style)
    allocated_width = @allocated_width - self.width
    # FIXME: さらに子のmarginから幅を計算する必要があるが後回し
    child = TypesetInline.new(self, inline_style, text_style, allocated_width)
    @children.push child
    child
  end

  def new_text
    allocated_width = @allocated_width - self.width
    child = TypesetText.new(self, allocated_width)
    @children.push child
    child
  end

  def new_image
    # FIXME: not yet
  end

  def break_line
    @next = @parent.break_line

    # FIXME: 最後の子要素が空なら取り除くとか必要かも

    adjust_stretch_width

    last_child = @children.last
    case last_child
    when TypesetInline
      @next.new_inline(last_child.text_style)
    when TypesetText
      @next.new_text
    #when TypesetImage  # FIXME: not yet
      #@next.new_image
    end
  end

  def write_to(content)
    x = 0
    @children.each do |child|
      content.stack_graphic_state do
        # 自身のascenderの高さが基準で、子のascenderの高さにy軸の位置を持っていく
        child_y = child.ascender - self.ascender
        content.move_origin x, child_y
        child.write_to(content)
        # この間のmarginの計算も必要だけど後回し
        x += child.width
      end
    end
  end

  private

  def adjust_stretch_width
    stretch_count = self.stretch_count
    if stretch_count > 0
      stretch_width = (@allocated_width - self.width) / stretch_count
      self.stretch_width = stretch_width
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

  class TypesetBlockMock
    def initialize(text_style, allocated_width)
      @text_style = text_style
      @allocated_width = allocated_width
      @children = []
    end

    attr_reader :text_style, :allocated_width

    def add_child(child)
      @children.push child
    end

    def break_line
      line = TypesetLine.new(self, @allocated_width)
      add_child(line)
      line
    end

    def write_to(content)
      @children.each do |child|
        child.write_to(content)
      end
    end
  end

  using LengthExtension

  sfnt_font = SfntFont.load('ipaexm.ttf')
  pdf_font = PdfFont.new(sfnt_font)
  font_size = 14

  text_style = TextStyle.new(font: pdf_font, size: font_size, verbatim: false)

  block = TypesetBlockMock.new(text_style, 5.cm)
  line = TypesetLine.new(block, 5.cm)
  block.add_child(line)

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

  page = PdfPage.add_to(document)
  page.add_content do |content|
    block.write_to(content)
  end

  binder = PdfObjectBinder.new
  # pageの内容だけ見る
  page.attach_to(binder)

  binder.serialized_objects.each do |serialized_object|
    puts serialized_object
  end
end
