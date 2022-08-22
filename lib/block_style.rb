# ブロック要素のスタイル

require_relative 'typeset_margin'
require_relative 'typeset_padding'

class BlockStyle

  # FIXME: あとでborderも追加

  def initialize(margin: TypesetMargin.zero, padding: TypesetPadding.zero,
                 line_gap: nil, begin_new_page: false, indent: 0)
    @margin = margin
    @padding = padding
    @line_gap = line_gap
    @begin_new_page = begin_new_page
    @indent = indent
  end

  def create_inherit_style(parent_style)
    line_gap = @line_gap || parent_style.line_gap
    BlockStyle.new(margin: @margin, padding: @padding,
                   line_gap: line_gap, begin_new_page: @begin_new_page, indent: @indent)
  end

  attr_reader :margin, :padding
  attr_reader :line_gap, :begin_new_page, :indent
  alias_method :begin_new_page?, :begin_new_page

end
