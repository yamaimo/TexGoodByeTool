# 組版オブジェクト：テキスト

require_relative 'margin'
require_relative 'text_style'
require_relative 'typeset_char'
require_relative 'typeset_space'

class TypesetText
  # child: TypesetChar | TypesetSpace
  #   require: #width, #write_with, #stretch?, #strut?,
  #            TypesetChar.create, TypesetChar#to_s,
  #            TypesetSpace.new_stretch, TypesetSpace.new_fix, TypesetSpace.new_strut,
  #            TypesetSpace#stretch_count, TypesetSpace#width=
  #   required: -
  # parent: TypesetLine | TypesetInline
  #   require: #text_style, #break_line, #adjust_stretch_width
  #   required: #margin, #width, #ascender, #descender,
  #             #stretch_count, #stretch_width=, #empty?, #write_to
  # next:
  #   require: #latest, #add_char
  # other:
  #   required: (not yet)

  RESTRICT_FIRST_CHARS = ")]}>,.;:!?）」』、。；：！？ぁぃぅぇぉっゃゅょァィゥェォッャュョ\u00a0"
  RESTRICT_LAST_CHARS = " ([{<（「『\u00a0" # \u00a0はnbsp
  ALNUM_REGEXP = Regexp.new(/[a-zA-Z0-9]/)

  def initialize(parent, allocated_width)
    @parent = parent
    @allocated_width = allocated_width
    @text_style = @parent.text_style
    @chars = []     # TypesetChar, TypesetSpace
    @stretches = [] # TypesetSpaceのみ
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
    @text_style.font.ascender * @text_style.size / 1000.0
  end

  def descender
    # FIXME: あとでtext_riseも足す
    @text_style.font.descender * @text_style.size / 1000.0
  end

  def margin
    Margin.zero
  end

  def stretch_count
    @stretches.map(&:stretch_count).sum || 0
  end

  def stretch_width=(width)
    @stretches.each do |stretch|
      stretch.width = width * stretch.stretch_count
    end
  end

  def latest
    @next.nil? ? self : @next.latest
  end

  def empty?
    @chars.empty?
  end

  def add_char(char)
    puts "TypesetText#add_char (char: #{char})" # debug

    last_child = @chars.empty? ? nil : @chars.last

    # 最後にstrutが入っていた場合、遅延させていた改行を実行してから文字を追加
    # （遅延させないと空行ができる可能性がある）
    if last_child&.strut?
      @next = @parent.break_line
      @parent.adjust_stretch_width
      @next.add_char(char)
      return
    end

    last_char = last_child&.is_a?(TypesetChar) ? last_child.to_s : nil

    # 改行文字の場合、
    # 1. verbatimならstrutを入れて終了（改行は遅延させる）
    # 2. そうでない場合、
    #    a. 直前が英数字なら改行のかわりに半角スペースを追加
    #    b. そうでなければ何もせずに終了
    if char == "\n"
      if @text_style.verbatim?
        @chars.push TypesetSpace.new_strut
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
      self.add_stretch
    end

    # 組版文字を作って追加する
    typeset_char = TypesetChar.create(char, @text_style.font, @text_style.size)
    @chars.push typeset_char

    # 幅がオーバーするようだったら改行処理
    if self.width > @allocated_width
      next_line_str = pop_next_line_str
      @next = @parent.break_line
      @parent.adjust_stretch_width
      next_line_str.each_char do |char|
        @next.add_char(char)
      end
    end
  end

  def add_space(width)
    space = TypesetSpace.new_fix(@text_style.size, width)
    @chars.push space
  end

  def add_stretch(count=1)
    stretch = TypesetSpace.new_stretch(@text_style.size, count)
    @chars.push stretch
    @stretches.push stretch
  end

  def write_to(content, upper_left_x, upper_left_y)
    child_x = upper_left_x
    baseline_y = upper_left_y - self.ascender
    content.stack_graphic_state do
      content.move_origin child_x, baseline_y
      puts "TypesetText#write_to (x: #{child_x}, y: #{baseline_y})"  # debug
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
      if char.stretch?
        @stretches.pop
        ""
      elsif char.is_a?(TypesetChar)
        char.to_s
      else
        # 固定スペースがもしかしたら来るかもしれない
        # その場合は直前に改行位置があるので、単に取り除くことにする
        ""
      end
    end.join.lstrip
  end

end

if __FILE__ == $0
  # not yet
end
