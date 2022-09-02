# マージン

class Margin

  def self.zero
    @zero ||= self.new
  end

  def self.calc_collapsing(margin1, margin2)
    if (margin1 >= 0) && (margin2 >= 0)
      [margin1, margin2].max
    elsif (margin1 <= 0) && (margin2 <= 0)
      [margin1, margin2].min
    else
      margin1 + margin2
    end
  end

  def initialize(top: 0, right: 0, bottom: 0, left: 0)
    @top = top
    @right = right
    @bottom = bottom
    @left = left
  end

  attr_reader :top, :right, :bottom, :left

  def updated(top: nil, right: nil, bottom: nil, left: nil)
    self.class.new(
      top: (top || @top),
      right: (right || @right),
      bottom: (bottom || @bottom),
      left: (left || @left))
  end

end
