# 組版マージン

class TypesetMargin

  def self.zero_margin
    @zero_margin ||= self.new
  end

  def initialize(top: 0, right: 0, bottom: 0, left: 0)
    @top = top
    @right = right
    @bottom = bottom
    @left = left
  end

  attr_reader :top, :right, :bottom, :left

end
