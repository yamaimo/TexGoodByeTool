# 組版オブジェクト：行

require_relative 'margin'
require_relative 'padding'
require_relative 'inline_style'
require_relative 'text_style'
require_relative 'typeset_inline'
require_relative 'typeset_text'
require_relative 'typeset_image'

class TypesetLine
  # child: TypesetInline | TypesetText | TypesetImage
  #   require: #margin, #width, #ascender, #descender,
  #            #stretch_count, #stretch_width=, #write_to
  #   required: #inline_style, #text_style, #break_line, #adjust_stretch_width
  # parent: TypesetBody | TypesetBlock
  #   require: #text_style, #break_line
  #   required: #margin, #width, #ascender, #descender, #height,
  #             #stretch_count, #stretch_width=,
  #             TypesetLine#update_parent, #empty?, #write_to
  # next:
  #   require: #latest
  # other:
  #   required: 

  # FIXME:
  # 子要素間に伸縮スペースを入れるか設定で必要そう。

  def initialize(parent, allocated_width)
    @parent = parent
    @allocated_width = allocated_width
    @inline_style = InlineStyle.new
    @text_style = @parent.text_style
    @allocated_width = allocated_width
    @children = []
    @next = nil
  end

  attr_reader :inline_style, :text_style, :allocated_width

  def width
    width = 0

    prev_child = nil
    @children.each do |child|
      if prev_child.nil?
        width += child.margin.left
      else
        width += Margin.calc_collapsing(prev_child.margin.right, child.margin.left)
      end
      width += child.width
      prev_child = child
    end
    width += prev_child.margin.right if prev_child

    width
  end

  def height
    self.ascender - self.descender
  end

  def ascender
    @children.map do |child|
      child.ascender + child.margin.top
    end.max || 0
  end

  def descender
    @children.map do |child|
      child.descender - child.margin.bottom
    end.min || 0
  end

  def margin
    Margin.zero
  end

  def padding
    Padding.zero
  end

  def update_parent
    @parent = @parent.latest
  end

  def latest
    @next.nil? ? self : @next.latest
  end

  def empty?
    @children.empty?
  end

  def new_inline(inline_style, text_style)
    allocated_width = @allocated_width - self.width
    if @children.empty?
      allocated_width -= (inline_style.margin.left + inline_style.margin.right)
    else
      last_child = @children.last
      allocated_width += last_child.margin.right
      allocated_width -= Margin.calc_collapsing(last_child.margin.right, inline_style.margin.left)
      allocated_width -= inline_style.margin.right
    end
    child = TypesetInline.new(self, inline_style, text_style, allocated_width)
    @children.push child
    child
  end

  def new_text
    allocated_width = @allocated_width - self.width
    # textはマージンが0なのでそのまま使える
    child = TypesetText.new(self, allocated_width)
    @children.push child
    child
  end

  def new_image(pdf_image)
    child = TypesetImage.new(pdf_image)
    @children.push child
    child
  end

  def break_line
    puts "TypesetLine#break_line"  # debug

    # 子が空になっている場合、あらかじめ取り除いておく
    last_child = @children.last
    @children.pop if last_child.empty?

    @next = @parent.break_line

    case last_child
    when TypesetInline
      @next.new_inline(last_child.inline_style, last_child.text_style)
    when TypesetText
      @next.new_text
    when TypesetImage
      # imageからbreak_lineは呼ばれないので、ここに来ることはない
      raise "Invalid state (last child is image)."
    end
  end

  def adjust_stretch_width
    stretch_count = @children.map(&:stretch_count).sum
    if stretch_count > 0
      stretch_width = (@allocated_width - self.width) / stretch_count
      @children.each do |child|
        child.stretch_width = stretch_width
      end
    end
  end

  def write_to(content, upper_left_x, upper_left_y)
    child_x = upper_left_x
    prev_child = nil
    @children.each do |child|
      if prev_child.nil?
        child_x += child.margin.left
      else
        child_x += Margin.calc_collapsing(prev_child.margin.right, child.margin.left)
      end

      # 自身のascenderの高さが基準で、子のascenderの高さにy軸の位置を持っていく
      child_y = upper_left_y - self.ascender + child.ascender

      puts "TypesetLine#write_to (x: #{child_x}, y: #{child_y})"  # debug
      child.write_to(content, child_x, child_y)

      child_x += child.width
      prev_child = child
    end
  end

end

if __FILE__ == $0
  # not yet
end
