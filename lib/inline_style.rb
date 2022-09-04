# インライン要素のスタイル

require_relative 'border'
require_relative 'margin'
require_relative 'padding'

class InlineStyle

  # FIXME: 他、backgroundやnobreakなども必要そう

  def initialize
    @border = Border.new
    @margin = Margin.zero
    @padding = Padding.zero
  end

  attr_reader :border, :margin, :padding

  def border=(border)
    @border = border if border
  end

  def margin=(margin)
    @margin = margin if margin
  end

  def padding=(padding)
    @padding = padding if padding
  end

  def create_inherit_style(parent_style)
    # 今のところ継承するものはないけど、
    # nobreakは継承（強制的な上書き）が必要になる
    self.dup
  end

end

if __FILE__ == $0
  # not yet
end
