# ページのスタイル

require_relative 'typeset_margin'
require_relative 'typeset_padding'

class PageStyle

  def initialize
    @margin = TypesetMargin.zero_margin
    @padding = TypesetPadding.zero_padding
    @to_footer_gap = 0

    # FIXME: フッタのレイアウトもDomHandlerに委譲したい
    # そうすればこの設定は不要になる（ブロックの設定でOK）
    @footer_sfnt_font = nil
    @footer_font_size = nil
  end

  attr_accessor :margin, :padding, :to_footer_gap
  attr_accessor :footer_sfnt_font, :footer_font_size

end
