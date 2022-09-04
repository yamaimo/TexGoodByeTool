# 組版オブジェクト：本文領域

require_relative 'margin'
require_relative 'padding'
require_relative 'block_style'
require_relative 'text_style'
require_relative 'typeset_block'
require_relative 'typeset_line'

class TypesetBody
  # child: TypesetBlock | TypesetLine
  #   require: #margin, #width, #height
  #            TypesetBlock#block_style, #text_style
  #            TypesetLine#update_parent, #write_to, #empty?
  #   required: #block_style, #text_style, #break_page, #page_top?
  # parent: TypesetPage
  #   require: #break_page
  #   required: #block_style, #text_style, #write_to
  # next:
  #   require: #push_line, #new_block
  # other:
  #   required: #current_line

  def initialize(parent, text_style, line_gap, allocated_width, allocated_height)
    @parent = parent
    @block_style = BlockStyle.new
    @block_style.line_gap = line_gap
    @text_style = text_style
    @allocated_width = allocated_width
    @allocated_height = allocated_height
    @children = []
    @next = nil
  end

  attr_reader :block_style, :text_style, :allocated_width, :allocated_height

  def width
    @children.map do |child|
      child.width + child.margin.left + child.margin.right
    end.max || 0
  end

  def height
    height = 0

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

    height
  end

  def margin
    Margin.zero
  end

  def padding # いらないかも
    Padding.zero
  end

  def latest  # いらないかも
    @next.nil? ? self : @next.latest
  end

  def empty?  # いらないかも
    @children.empty?
  end

  # ページの先頭にいるか
  def page_top?
    @children.size <= 1
  end

  def new_block(block_style, text_style)
    allocated_width = @allocated_width
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
    child = TypesetLine.new(self, @allocated_width)
    @children.push child
    child
  end

  # 現在の行を返す（なければ作って返す）
  def current_line
    if @children.empty?
      # インデントは設定が0なので不要
      self.new_line
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
    puts "TypesetBody#break_line"  # debug

    # 改ページが必要になってる場合、改ページして新しい行を返す
    # そうでない場合、単に新しい行を返す
    if self.height > @allocated_height
      puts "height: #{self.height}, allocated_height: #{@allocated_height}" # debug
      self.break_page
      @next.new_line
    else
      self.new_line
    end
  end

  def break_page
    puts "TypesetBody#break_page"  # debug

    # 子がいない状態で呼ばれたら、単に親に依頼する
    if @children.empty?
      @next = @parent.break_page
      return
    end

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

    @next = @parent.break_page

    case last_child
    when TypesetBlock
      @next.new_block(last_child.block_style, last_child.text_style)
    when TypesetLine
      last_child.update_parent  # 新しいブロックが親になるようにする
      @next.push_line last_child
      last_child
    end
  end

  def write_to(content, upper_left_x, upper_left_y)
    child_y = upper_left_y
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

      child_x = upper_left_x + child.margin.left

      puts "TypesetBody#write_to (x: #{child_x}, y: #{child_y})"  # debug
      child.write_to(content, child_x, child_y)

      child_y -= child.height
      prev_child = child
    end
  end

end

if __FILE__ == $0
  # not yet
end
