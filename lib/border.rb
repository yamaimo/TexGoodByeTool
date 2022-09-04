# 境界線

require_relative 'pdf_graphic'

class Border

  class Line

    # FIXME: colorや破線パターン、二重線などの指定もありそう

    def initialize
      @width = 0
    end

    attr_reader :width

    def width=(width)
      @width = width if width
    end

    def to_pdf_graphic_setting
      setting = PdfGraphic::Setting.new
      setting.line_width = @width
      setting
    end

  end

  # FIXME: 角丸の指定などもありそう

  def initialize
    @top = Line.new
    @right = Line.new
    @bottom = Line.new
    @left = Line.new
  end

  attr_reader :top, :right, :bottom, :left

  # 設定がないのに呼ばれるのは無駄なので、簡易チェックする
  def has_valid_line?
    [@top, @right, @bottom, @left].any? {|line| line.width > 0}
  end

  def write_to(content, left_x, right_x, upper_y, lower_y, disabled=[])
    lines = {top: @top, right: @right, bottom: @bottom, left: @left}
    points = {
      top: {from: [left_x, upper_y], to: [right_x, upper_y]},
      right: {from: [right_x, upper_y], to: [right_x, lower_y]},
      bottom: {from: [left_x, lower_y], to: [right_x, lower_y]},
      left: {from: [left_x, upper_y], to: [left_x, lower_y]},
    }

    [:top, :right, :bottom, :left].each do |target|
      line = lines[target]
      point = points[target]
      if (line.width > 0) && (not disabled.include?(target))
        line.to_pdf_graphic_setting.get_pen_for(content) do |pen|
          path = PdfGraphic::Path.new { from point[:from]; to point[:to] }
          pen.stroke path
        end
      end
    end
  end

end

if __FILE__ == $0
  # not yet
end
