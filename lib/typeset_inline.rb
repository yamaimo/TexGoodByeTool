# 組版オブジェクト：インライン要素

require_relative 'margin'
require_relative 'typeset_text'
require_relative 'typeset_image'

class TypesetInline
  # FIXME: このコメントを不要にしたい（ちゃんと整理できてない）
  # child: TypesetInline | TypesetText | TypesetImage
  #   require: #margin, #width, #ascender, #descender,
  #            #stretch_count, #stretch_width=,
  #            #empty?, #write_to
  #   required: #text_style, #break_line, #adjust_stretch_width
  # parent: TypesetLine | TypesetInline
  #   require: #inline_style, #text_style, #break_line, #adjust_stretch_width
  #   required: #margin, #width, #ascender, #descender,
  #             #stretch_count, #stretch_width=,
  #             #empty?, #write_to
  # next:
  #   require: #latest, #prev=, #new_inline, #new_text, #new_image
  # other:
  #   required: (not yet)

  # FIXME:
  # 子要素間に伸縮スペースを入れるかと、
  # 子要素間での改行を許すかは、設定で必要そう。

  def initialize(parent, inline_style, text_style, allocated_width)
    @parent = parent
    @inline_style = inline_style.create_inherit_style(parent.inline_style)
    @text_style = text_style.create_inherit_style(parent.text_style)
    @allocated_width = allocated_width
    @children = []
    @prev = nil
    @next = nil
    @margin = nil   # キャッシュ
    @padding = nil  # キャッシュ
  end

  attr_reader :inline_style, :text_style, :allocated_width

  def width
    # FIXME: borderの幅も追加すべきだけど後回し
    width = self.padding.left

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

    width += self.padding.right
  end

  def height
    self.ascender - self.descender
  end

  def ascender
    # FIXME: borderの幅も追加すべきだけど後回し
    child_ascender = @children.map do |child|
      child.ascender + child.margin.top
    end.max || 0
    child_ascender + self.padding.top
  end

  def descender
    # FIXME: borderの幅も追加すべきだけど後回し
    child_descender = @children.map do |child|
      child.descender - child.margin.bottom
    end.min || 0
    child_descender - self.padding.bottom
  end

  def margin
    @margin ||= begin
      left = @prev ? 0 : nil
      right = @next ? 0 : nil
      @inline_style.margin.updated(left: left, right: right)
    end
  end

  def padding
    @padding ||= begin
      left = @prev ? 0 : nil
      right = @next ? 0 : nil
      @inline_style.padding.updated(left: left, right: right)
    end
  end

  def stretch_count
    @children.map(&:stretch_count).sum
  end

  def stretch_width=(width)
    @children.each do |child|
      child.stretch_width = width
    end
  end

  def prev=(prev_inline)
    @prev = prev_inline
    # キャッシュクリア
    @margin = nil
    @padding = nil
  end

  def next=(next_inline)
    @next = next_inline
    # キャッシュクリア
    @margin = nil
    @padding = nil
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
    # 子が空になっている場合、あらかじめ取り除いておく
    # （これで自身も空になれば親から取り除かれる）
    last_child = @children.last
    @children.pop if last_child.empty?

    self.next = @parent.break_line

    # 自身が空になっている場合親から取り除かれるので、
    # 新しい要素が最初の要素になる
    # なので、自身が空でない場合だけ、次の要素の前の要素を自身にする
    @next.prev = self unless self.empty?

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
    @parent.adjust_stretch_width
  end

  def write_to(content, left_x, upper_y)
    border = @inline_style.border
    if border.has_valid_line?
      right_x = left_x + self.width
      lower_y = upper_y - self.height
      disabled = []
      disabled.push :left if @prev
      disabled.push :right if @next
      border.write_to(content, left_x, right_x, upper_y, lower_y, disabled)
    end

    # FIXME: borderの幅も追加すべきだけど後回し
    child_x = left_x + self.padding.left
    prev_child = nil
    @children.each do |child|
      if prev_child.nil?
        child_x += child.margin.left
      else
        child_x += Margin.calc_collapsing(prev_child.margin.right, child.margin.left)
      end

      # 自身のascenderの高さが基準で、子のascenderの高さにy軸の位置を持っていく
      child_y = upper_y - self.ascender + child.ascender

      child.write_to(content, child_x, child_y)

      child_x += child.width
      prev_child = child
    end
  end

end

if __FILE__ == $0
  # not yet
end
