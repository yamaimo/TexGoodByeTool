# 組版オブジェクト：ブロック要素

require_relative 'margin'
require_relative 'typeset_line'

class TypesetBlock
  # FIXME: このコメントを不要にしたい（ちゃんと整理できてない）
  # child: TypesetBlock | TypesetLine
  #   require: #margin, #width, #height,
  #            TypesetBlock#block_style, #text_style
  #            TypesetLine#update_parent, #write_to, #empty?
  #   required: #block_style, #text_style, #break_line, #break_page
  # parent: TypesetBody | TypesetBlock
  #   require: #block_style, #text_style, #break_page, #page_top?
  #   required: #margin, #width, #height
  #             TypesetBlock#block_style, #text_style
  #             TypesetLine#update_parent, #write_to, #empty?
  # next:
  #   require: #new_block, #new_line, #push_line
  # other:
  #   required: #current_line

  def initialize(parent, block_style, text_style, allocated_width, allocated_height)
    @parent = parent
    @block_style = block_style.create_inherit_style(parent.block_style)
    @text_style = text_style.create_inherit_style(parent.text_style)
    @allocated_width = allocated_width
    @allocated_height = allocated_height
    @children = []
    @prev = nil
    @next = nil
    @margin = nil   # キャッシュ
    @padding = nil  # キャッシュ
  end

  attr_reader :block_style, :text_style, :allocated_width, :allocated_height

  def width
    # FIXME: borderの幅も追加すべきだけど後回し
    child_width = @children.map do |child|
      child.width + child.margin.left + child.margin.right
    end.max || 0
    child_width + self.padding.left + self.padding.right
  end

  def height
    # FIXME: borderの幅も追加すべきだけど後回し
    height = self.padding.top

    prev_child = nil
    @children.each do |child|
      if prev_child.nil?
        height += child.margin.top
      else
        height += Margin.calc_collapsing(prev_child.margin.bottom, child.margin.top)
        if prev_child.is_a?(TypesetLine) && child.is_a?(TypesetLine)
          height += @block_style.line_gap
        end
      end
      height += child.height
      prev_child = child
    end
    height += prev_child.margin.bottom if prev_child

    height += self.padding.bottom
  end

  def margin
    @margin ||= begin
      top = @prev ? 0 : nil
      bottom = @next ? 0 : nil
      @block_style.margin.updated(top: top, bottom: bottom)
    end
  end

  def padding
    @padding ||= begin
      top = @prev ? 0 : nil
      bottom = @next ? 0 : nil
      @block_style.padding.updated(top: top, bottom: bottom)
    end
  end

  def prev=(prev_block)
    @prev = prev_block
    # キャッシュクリア
    @margin = nil
    @padding = nil
  end

  def next=(next_block)
    @next = next_block
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

  # ページの先頭にいるか
  def page_top?
    (@children.size > 1) ? false : @parent.page_top?
  end

  def new_block(block_style, text_style)
    allocated_width = @allocated_width
    allocated_width -= (self.padding.left + self.padding.right)
    allocated_width -= (block_style.margin.left + block_style.margin.right)

    allocated_height = @allocated_height - self.height
    if @children.empty?
      allocated_height -= (block_style.margin.top + block_style.margin.bottom)
    else
      last_child = @children.last
      allocated_height += last_child.margin.bottom
      allocated_height -= Margin.calc_collapsing(last_child.margin.bottom, block_style.margin.top)
      allocated_height -= block_style.margin.bottom
    end

    child = TypesetBlock.new(self, block_style, text_style, allocated_width, allocated_height)
    @children.push child
    child
  end

  def new_line
    allocated_width = @allocated_width
    allocated_width -= (self.padding.left + self.padding.right)
    child = TypesetLine.new(self, allocated_width)
    @children.push child
    child
  end

  # 現在の行を返す（なければ作って返す）
  def current_line
    if @children.empty?
      line = self.new_line
      # 最初の行なので、必要ならインデントする
      if @block_style.indent != 0
        indent_size = @text_style.size * @block_style.indent
        text = line.new_text
        text.add_space(indent_size)
      end
      line
    elsif @children.last.is_a?(TypesetBlock)
      self.new_line
    else
      @children.last
    end
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
    # 子がいない状態で呼ばないこと
    # （一番最後の子がコピーされるため）
    raise "Invalid state (no children)." if @children.empty?

    last_child = @children.last
    # 子が空になっている場合、あらかじめ取り除いておく
    # （これで自身も空になれば親から取り除かれる）
    # そうでない場合も、子がTypesetLineなら高さをチェックし、
    # 次のページに移す必要がある場合は取り除いておく
    if last_child.empty?
      @children.pop
    elsif last_child.is_a?(TypesetLine) && (self.height > @allocated_height)
      @children.pop
    end

    self.next = @parent.break_page

    # 自身が空になっている場合親から取り除かれるので、
    # 新しい要素が最初の要素になる
    # なので、自身が空でない場合だけ、次の要素の前の要素を自身にする
    @next.prev = self unless self.empty?

    case last_child
    when TypesetBlock
      @next.new_block(last_child.block_style, last_child.text_style)
    when TypesetLine
      last_child.update_parent  # 新しいブロックが親になるようにする
      @next.push_line last_child
      last_child
    end
  end

  def write_to(content, left_x, upper_y)
    border = @block_style.border
    if border.has_valid_line?
      right_x = left_x + @allocated_width # 幅いっぱいまで引く
      lower_y = upper_y - self.height
      disabled = []
      disabled.push :top if @prev
      disabled.push :bottom if @next
      border.write_to(content, left_x, right_x, upper_y, lower_y, disabled)
    end

    # FIXME: borderの幅も追加すべきだけど後回し
    child_y = upper_y - self.padding.top
    prev_child = nil
    @children.each do |child|
      if prev_child.nil?
        child_y -= child.margin.top
      else
        child_y -= Margin.calc_collapsing(prev_child.margin.bottom, child.margin.top)
        if prev_child.is_a?(TypesetLine) && child.is_a?(TypesetLine)
          child_y -= @block_style.line_gap
        end
      end

      child_x = left_x + self.padding.left + child.margin.left

      child.write_to(content, child_x, child_y)

      child_y -= child.height
      prev_child = child
    end
  end

end

if __FILE__ == $0
  # not yet
end
