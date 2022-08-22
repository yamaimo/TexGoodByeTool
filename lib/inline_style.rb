# インライン要素のスタイル

require_relative 'typeset_margin'
require_relative 'typeset_padding'

class InlineStyle

  # FIXME: あとでborderも追加

  def initialize(margin: TypesetMargin.zero, padding: TypesetPadding.zero)
    @margin = margin
    @padding = padding
  end

  attr_accessor :margin, :padding

end
