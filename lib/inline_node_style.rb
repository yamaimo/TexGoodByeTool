# インライン要素のスタイル

class InlineNodeStyle

  def initialize
    @sfnt_font = nil
    @ignore_line_feed = true
    # FIXME: 本来はフォントサイズ指定できるべき
    # 指定なしの場合継承するという仕組みも必要
  end

  attr_accessor :sfnt_font
  attr_accessor :ignore_line_feed

end
