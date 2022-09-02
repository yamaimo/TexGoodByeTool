# ページのスタイル

require_relative 'margin'
require_relative 'padding'

class PageStyle

  # FIXME: ヘッダ、フッタの設定も追加したい

  def initialize
    @margin = Margin.zero
    @padding = Padding.zero
    @to_footer_gap = 0
  end

  attr_reader :margin, :padding, :to_footer_gap

  def margin=(margin)
    @margin = margin if margin
  end

  def padding=(padding)
    @padding = padding if padding
  end

  def to_footer_gap=(gap)
    @to_footer_gap = gap if gap
  end

end

if __FILE__ == $0
  # not yet
end
