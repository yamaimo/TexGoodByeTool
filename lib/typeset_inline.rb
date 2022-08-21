# 組版オブジェクト：インライン要素

require_relative 'typeset_text'

class TypesetInline
  # 子としてTypesetInline, TypesetText, TypesetImageを持ち、
  # これらに#width, #ascender, #descender,
  # #stretch_count, #stretch_width=, #write_to(content)を要求する。
  # 親はTypesetLineもしくはTypesetInlineで、
  # これらに#text_setting, #break_lineを要求する。

  # FIXME:
  # 子要素間に伸縮スペースを入れるかと、
  # 子要素間での改行を許すかは、設定で必要そう。

  # FIXME:
  # border, margin, paddingなども設定として持つが、後回し。

  def initialize(parent, text_setting, allocated_width = 0)
    @parent = parent
    @text_setting = text_setting
    @allocated_width = allocated_width
    @children = []
  end

  attr_reader :text_setting, :allocated_width

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

  def stretch_count
    @children.map(&:stretch_count).sum
  end

  def stretch_width=(width)
    @children.each do |child|
      child.stretch_width = width
    end
  end

  def new_inline(text_setting)
    allocated_width = @allocated_width - self.width
    # FIXME: さらに自身のpadding, 子のmarginから幅を計算する必要があるが後回し
    child = TypesetInline.new(self, text_setting, allocated_width)
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
    new_inline = @parent.break_line
    last_child = @children.last
    case last_child
    when TypesetInline
      new_inline.new_inline(last_child.text_setting)
    when TypesetText
      new_inline.new_text
    #when TypesetImage  # FIXME: not yet
      #new_inline.new_image
    end
  end

  def write_to(content)
    # FIXME: 自身の境界線を引いたりpaddingスキップしたりが必要だけど後回し
    x = 0
    @children.each do |child|
      content.stack_graphic_state do
        # y軸は自身のascenderの位置が基準になって子のascenderの位置に原点を持っていく
        child_y = child.ascender - self.ascender
        content.move_origin x, child_y
        child.write_to(content)
        # この間のmarginの計算も必要だけど後回し
        x += child.width
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
  require_relative 'text_setting'

  class TypesetLineMock
    def initialize(text_setting, allocated_width)
      @text_setting = text_setting
      @allocated_width = allocated_width
      @children = []
    end

    attr_reader :text_seting, :allocated_width

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
                TypesetInline.new(self, last_child.text_setting, @allocated_width)
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

  text_setting = TextSetting.new(font: pdf_font, size: font_size, verbatim: false)

  line = TypesetLineMock.new(text_setting, 5.cm)
  inline = TypesetInline.new(line, text_setting, 5.cm)
  line.add_child(inline)

  script = <<~END_OF_SCRIPT
    二人の若い紳士が、すっかりイギリスの兵隊のかたちをして、
    ぴかぴかする鉄砲をかついで、歩いておりました。
    Two young gentlemen were walking along,
    fully dressed as British soldiers, carrying shiny guns.
  END_OF_SCRIPT

  text = inline.new_text
  script.each_char do |char|
    text = text.add_char(char)
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
