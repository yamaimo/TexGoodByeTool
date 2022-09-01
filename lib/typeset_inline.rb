# 組版オブジェクト：インライン要素

require_relative 'typeset_text'

class TypesetInline
  # 子としてTypesetInline, TypesetText, TypesetImageを持ち、
  # これらに#width, #ascender, #descender, #margin
  # #stretch_count, #stretch_width=, #write_to(content)を要求する。
  # 親はTypesetLineもしくはTypesetInlineで、
  # これらに#text_style, #break_lineを要求する。

  # FIXME:
  # 子要素間に伸縮スペースを入れるかと、
  # 子要素間での改行を許すかは、設定で必要そう。

  def initialize(parent, inline_style, text_style, allocated_width)
    @parent = parent
    @inline_style = inline_style
    @text_style = text_style.create_inherit_style(parent.text_style)
    @allocated_width = allocated_width
    @children = []
    @next = nil
  end

  attr_reader :inline_style, :text_style, :allocated_width

  def width
    # FIXME: 自身のpadding, 子の間のmarginの計算が必要だけど後回し
    @children.map(&:width).sum
  end

  def height
    self.ascender - self.descender
  end

  def ascender
    # FIXME: 自身のpadding, 子のmarginの計算も必要だけど後回し
    @children.map(&:ascender).max || 0
  end

  def descender
    # FIXME: 自身のpadding, 子のmarginの計算も必要だけど後回し
    @children.map(&:descender).min || 0
  end

  def margin
    @inline_style.margin
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
    # FIXME: さらに自身のpadding, 子のmarginから幅を計算する必要があるが後回し
    child = TypesetInline.new(self, inline_style, text_style, allocated_width)
    @children.push child
    child
  end

  def new_text
    allocated_width = @allocated_width - self.width
    # FIXME: さらに自身のpaddingから幅を計算する必要があるが後回し
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

    last_child = @children.last
    case last_child
    when TypesetInline
      @next.new_inline(last_child.inline_style, last_child.text_style)
    when TypesetText
      @next.new_text
    #when TypesetImage  # FIXME: not yet
      #@next.new_image
    end
  end

  def write_to(content, upper_left_x, upper_left_y)
    # FIXME: 自身の境界線を引いたりpaddingスキップしたりが必要だけど後回し
    x = upper_left_x
    @children.each do |child|
      # 自身のascenderの高さが基準で、子のascenderの高さにy軸の位置を持っていく
      child_y = upper_left_y - self.ascender + child.ascender
      puts "TypesetLine#write_to (x: #{x}, y: #{child_y})"  # debug
      child.write_to(content, x, child_y)
      # この間のmarginの計算も必要だけど後回し
      x += child.width
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
  require_relative 'inline_style'

  class TypesetLineMock
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
      last_child = @children.last

      stretch_count = last_child.stretch_count
      if stretch_count > 0
        stretch_width = (@allocated_width - last_child.width) / stretch_count
        last_child.stretch_width = stretch_width
      end

      child = case last_child
              when TypesetInline
                TypesetInline.new(self, last_child.inline_style, last_child.text_style, @allocated_width)
              when TypesetText
                TypesetText.new(self, @allocated_width)
              end
      add_child(child)
      child
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
  inline_style = InlineStyle.new

  line = TypesetLineMock.new(text_style, 5.cm)
  inline = TypesetInline.new(line, inline_style, text_style, 5.cm)
  line.add_child(inline)

  script = <<~END_OF_SCRIPT
    二人の若い紳士が、すっかりイギリスの兵隊のかたちをして、
    ぴかぴかする鉄砲をかついで、歩いておりました。
    Two young gentlemen were walking along,
    fully dressed as British soldiers, carrying shiny guns.
  END_OF_SCRIPT

  text = inline.new_text
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
    line.write_to(content)
  end

  binder = PdfObjectBinder.new
  # pageの内容だけ見る
  page.attach_to(binder)

  binder.serialized_objects.each do |serialized_object|
    puts serialized_object
  end
end
