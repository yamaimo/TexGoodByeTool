# ページのスタイル

require_relative 'typeset_margin'
require_relative 'typeset_padding'

class PageStyle

  def initialize(margin: TypesetMargin.zero, padding: TypesetPadding.zero,
                 to_footer_gap: 0)
    @margin = margin
    @padding = padding
    @to_footer_gap = to_footer_gap
  end

  attr_reader :margin, :padding, :to_footer_gap

end
