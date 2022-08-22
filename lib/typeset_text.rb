# 組版オブジェクト：テキスト

require_relative 'text_style'
require_relative 'typeset_char'
require_relative 'typeset_stretch_space'

class TypesetText
  # 子としてTypesetChar, TypesetStretchSpaceを持ち、
  # これらに#write_with(pen)を要求する。
  # 親はTypesetLineもしくはTypesetInlineで、
  # これらに#text_style, #break_lineを要求する。

  RESTRICT_FIRST_CHARS = ")]}>,.;:!?）」』、。；：！？ぁぃぅぇぉっゃゅょァィゥェォッャュョ\u00a0"
  RESTRICT_LAST_CHARS = " ([{<（「『\u00a0" # \u00a0はnbsp
  ALNUM_REGEXP = Regexp.new(/[a-zA-Z0-9]/)

  def initialize(parent, allocated_width = 0)
    @parent = parent  # TypesetLineもしくはTypesetInline
    @allocated_width = allocated_width
    @chars = []     # TypesetChar, TypesetStretchSpace
    @stretches = [] # TypesetStretchSpaceのみ
    @text_style = TextStyle.new(parent: @parent.text_style)
    @break_idx = 0  # 改行の位置
    @next = nil
  end

  def width
    @chars.map(&:width).sum
  end

  def height
    self.ascender - self.descender
  end

  def ascender
    # FIXME: あとでtext_riseも足す
    @text_style.font.ascender
  end

  def descender
    # FIXME: あとでtext_riseも足す
    @text_style.font.descender
  end

  def stretch_count
    @stretches.size
  end

  def stretch_width=(width)
    @stretches.each do |stretch|
      stretch.width = width
    end
  end

  def latest
    @next.nil? ? self : @next.latest
  end

  def add_char(char)
    last_char = @chars.empty? ? nil : @chars[-1].to_s

    # 改行文字の場合、
    # 1. verbatimなら改行して終了
    # 2. そうでない場合、
    #    a. 直前が英数字なら改行のかわりに半角スペースを追加
    #    b. そうでなければ何もせずに終了
    if char == "\n"
      if @text_style.verbatim?
        @next = @parent.break_line
        return
      else
        if replace_lf_to_space?(last_char)
          char = " "
        else
          return
        end
      end
    end

    # 直前で改行可能なら改行の位置を進めておく
    if breakable?(last_char, char)
      @break_idx = @chars.size
    end

    # 伸縮スペースが必要なら先に追加しておく
    if add_stretch?(last_char, char)
      stretch = TypesetStretchSpace.new(@text_style.size)
      @chars.push stretch
      @stretches.push stretch
    end

    # 組版文字を作って追加する
    typeset_char = TypesetChar.create(char, @text_style.font, @text_style.size)
    @chars.push typeset_char

    # 幅がオーバーするようだったら改行処理
    if width > @allocated_width
      next_line_str = pop_next_line_str
      @next = @parent.break_line
      next_line_str.each_char do |char|
        @next.add_char(char)
      end
    end
  end

  def write_to(content)
    content.stack_graphic_state do
      content.move_origin 0, -@text_style.font.ascender
      @text_style.to_pdf_text_setting.get_pen_for(content) do |pen|
        @chars.each do |char|
          char.write_with(pen)
        end
      end
    end
  end

  private

  def replace_lf_to_space?(last_char)
    return false if last_char.nil?
    last_char.ascii_only?
  end

  def breakable?(last_char, char)
    return false if last_char.nil?
    return false if RESTRICT_FIRST_CHARS.include?(char)
    return false if RESTRICT_LAST_CHARS.include?(last_char)
    return false if last_char.match?(ALNUM_REGEXP) && char.match?(ALNUM_REGEXP)
    return true
  end

  def add_stretch?(last_char, char)
    return false if last_char.nil?
    return false if @text_style.verbatim?
    return false if last_char.match?(ALNUM_REGEXP) && char.match?(ALNUM_REGEXP)
    return true
  end

  def pop_next_line_str
    # 改行の位置以降を取り出す
    next_line_chars = @chars[@break_idx..-1]
    @chars = @chars[0...@break_idx]

    # 改行の位置以降を文字列に戻す
    # このとき、次の行に移る伸縮スペースは取り除いておく
    # また、次の行の行頭にくる空白は取り除いておく（改行位置は空白の手前）
    next_line_chars.map do |char|
      if char.is_a?(TypesetStretchSpace)
        @stretches.pop
        ""
      else
        char.to_s
      end
    end.join.lstrip
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

  class TypesetLineMock
    def initialize(parent, text_style, allocated_width = 0)
      @parent = parent
      @text_style = text_style
      @allocated_width = allocated_width
      @children = []
    end

    attr_reader :text_style, :allocated_width

    def add_child(child)
      @children.push child
    end

    def break_line
      # 本来は親が作って追加する
      new_line = self.class.new(@parent, @text_style, @allocated_width)
      @parent.push new_line

      last_child = @children.last

      stretch_count = last_child.stretch_count
      if stretch_count > 0
        stretch_width = (@allocated_width - last_child.width) / stretch_count
        last_child.stretch_width = stretch_width
      end

      new_child = last_child.class.new(new_line, new_line.allocated_width)
      new_line.add_child(new_child)

      new_child
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

  lines = []
  line = TypesetLineMock.new(lines, text_style, 5.cm)
  text = TypesetText.new(line, 5.cm)
  line.add_child(text)

  script = <<~END_OF_SCRIPT
    二人の若い紳士が、すっかりイギリスの兵隊のかたちをして、
    ぴかぴかする鉄砲をかついで、歩いておりました。
    Two young gentlemen were walking along,
    fully dressed as British soldiers, carrying shiny guns.
  END_OF_SCRIPT

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
    lines.each do |line|
      line.write_to(content)
    end
  end

  binder = PdfObjectBinder.new
  # pageの内容だけ見る
  page.attach_to(binder)

  binder.serialized_objects.each do |serialized_object|
    puts serialized_object
  end
end
