# インライン要素のスタイル

require_relative 'margin'
require_relative 'padding'

class InlineStyle

  # FIXME: あとでborderも追加
  # 他、backgroundやnobreakなども必要そう

  def initialize
    @margin = Margin.zero
    @padding = Padding.zero
  end

  attr_reader :margin, :padding

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
