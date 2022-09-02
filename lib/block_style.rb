# ブロック要素のスタイル

require_relative 'margin'
require_relative 'padding'

class BlockStyle

  # FIXME: あとでborderも追加
  # 他、backgroundなども必要そう

  def initialize
    @margin = Margin.zero
    @padding = Padding.zero
    @line_gap = nil # 継承
    @begin_new_page = false
    @indent = 0
  end

  attr_reader :margin, :padding
  attr_reader :line_gap, :begin_new_page, :indent
  alias_method :begin_new_page?, :begin_new_page

  def margin=(margin)
    @margin = margin if margin
  end

  def padding=(padding)
    @padding = padding if padding
  end

  def line_gap=(gap)
    @line_gap = gap if gap
  end

  def begin_new_page=(bool)
    @begin_new_page = bool unless bool.nil?
  end

  def indent=(indent)
    @indent = indent if indent
  end

  def create_inherit_style(parent_style)
    style = self.dup
    style.line_gap = parent_style.line_gap if @line_gap.nil?
    style
  end

end

if __FILE__ == $0
  # not yet
end
