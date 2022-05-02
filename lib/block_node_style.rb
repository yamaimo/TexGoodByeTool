# ブロック要素のスタイル

require_relative 'typeset_margin'
require_relative 'typeset_padding'

class BlockNodeStyle

  def initialize
    @sfnt_font = nil
    @font_size = nil
    @line_gap = 0
    @margin = TypesetMargin.zero_margin
    @padding = TypesetPadding.zero_padding
    @begin_new_page = false
    @indent = 0
  end

  attr_accessor :sfnt_font, :font_size
  attr_accessor :line_gap, :margin, :padding
  attr_accessor :begin_new_page
  alias_method :begin_new_page?, :begin_new_page
  attr_accessor :indent

end
