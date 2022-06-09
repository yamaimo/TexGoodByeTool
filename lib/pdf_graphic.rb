# PDFグラフィックス

require_relative 'pdf_color'

class PdfGraphic

  class Path

    include Math

    private

    def initialize(&block)
      @operators = [] # 命令と引数の数
      @operands = []
      self.instance_eval(&block)
    end

    def initialize_copy(org)
      org_operators = org.instance_variable_get(:@operators)
      org_operands = org.instance_variable_get(:@operands)
      # deep copy
      @operators = Marshal.load(Marshal.dump(org_operators))
      @operands = Marshal.load(Marshal.dump(org_operands))
    end

    def from(point)
      @operators.push ["m", 1]
      @operands.push point
    end

    def to(point, ctrl1: nil, ctrl2: nil)
      case [ctrl1.nil?, ctrl2.nil?]
      when [true, true]
        @operators.push ["l", 1]
        @operands.push point
      when [false, true]
        @operators.push ["y", 2]
        @operands.push ctrl1
        @operands.push point
      when [true, false]
        @operators.push ["v", 2]
        @operands.push ctrl2
        @operands.push point
      when [false, false]
        @operators.push ["c", 3]
        @operands.push ctrl1
        @operands.push ctrl2
        @operands.push point
      end
    end

    def close
      @operators.push ["h", 0]
    end

    public

    def move(dx: 0, dy: 0)
      @operands = @operands.map{|x, y| [x + dx, y + dy]}
    end

    def scale(ratio: 1.0, anchor: [0, 0])
      self.move dx: -anchor[0], dy: -anchor[1]
      @operands = @operands.map{|x, y| [x * ratio, y * ratio]}
      self.move dx: anchor[0], dy: anchor[1]
    end

    def rotate(rad: 0, anchor: [0, 0])
      self.move dx: -anchor[0], dy: -anchor[1]
      @operands = @operands.map{|x, y| [cos(rad) * x - sin(rad) * y, sin(rad) * x + cos(rad) * y]}
      self.move dx: anchor[0], dy: anchor[1]
    end

    def h_flip(x: 0)
      self.move dx: -x
      @operands = @operands.map{|x, y| [-x, y]}
      self.move dx: x
    end

    def v_flip(y: 0)
      self.move dy: -y
      @operands = @operands.map{|x, y| [x, -y]}
      self.move dy: y
    end

    def to_pen_operand
      pen_operand = ""
      operand_index = 0
      @operators.each do |operator, operand_size|
        operands = @operands[operand_index, operand_size]
        pen_operand += operands.flatten.join(" ")
        pen_operand += " #{operator} "
        operand_index += operand_size
      end
      pen_operand
    end

  end

  class Rectangle < Path

    def initialize(point1, point2, round: 0)
      x1, y1 = point1
      x2, y2 = point2

      left_x = [x1, x2].min
      right_x = [x1, x2].max
      upper_y = [y1, y2].max
      lower_y = [y1, y2].min

      if round > 0
        width = right_x - left_x
        height = upper_y - lower_y
        round_max = [width, height].min / 2.0
        round = round.clamp(0.0, round_max)
      end

      super() do
        if round > 0
          ctrl = round * (4.0 / 3.0) * (sqrt(2) - 1)

          from [left_x + round, upper_y]
          to [right_x - round, upper_y]
          to [right_x, upper_y - round], \
            ctrl1: [right_x - round + ctrl, upper_y], \
            ctrl2: [right_x, upper_y - round + ctrl]
          to [right_x, lower_y + round]
          to [right_x - round, lower_y], \
            ctrl1: [right_x, lower_y + round - ctrl], \
            ctrl2: [right_x - round + ctrl, lower_y]
          to [left_x + round, lower_y]
          to [left_x, lower_y + round], \
            ctrl1: [left_x + round - ctrl, lower_y], \
            ctrl2: [left_x, lower_y + round - ctrl]
          to [left_x, upper_y - round]
          to [left_x + round, upper_y], \
            ctrl1: [left_x, upper_y - round + ctrl], \
            ctrl2: [left_x + round - ctrl, upper_y]
        else
          from [left_x, upper_y]
          to [right_x, upper_y]
          to [right_x, lower_y]
          to [left_x, lower_y]
          close
        end
      end

    end

  end

  class Oval < Path

    def initialize(point1, point2)
      x1, y1 = point1
      x2, y2 = point2

      left_x = [x1, x2].min
      right_x = [x1, x2].max
      middle_x = (x1 + x2) / 2.0
      upper_y = [y1, y2].max
      lower_y = [y1, y2].min
      middle_y = (y1 + y2) / 2.0

      h_ctrl = (right_x - middle_x) * (4.0 / 3.0) * (sqrt(2) - 1)
      v_ctrl = (upper_y - middle_y) * (4.0 / 3.0) * (sqrt(2) - 1)

      super() do
        from [middle_x, upper_y]
        to [right_x, middle_y], \
          ctrl1: [middle_x + h_ctrl, upper_y], \
          ctrl2: [right_x, middle_y + v_ctrl]
        to [middle_x, lower_y], \
          ctrl1: [right_x, middle_y - v_ctrl], \
          ctrl2: [middle_x + h_ctrl, lower_y]
        to [left_x, middle_y], \
          ctrl1: [middle_x - h_ctrl, lower_y], \
          ctrl2: [left_x, middle_y - v_ctrl]
        to [middle_x, upper_y], \
          ctrl1: [left_x, middle_y + v_ctrl], \
          ctrl2: [middle_x - h_ctrl, upper_y]
      end
    end

  end

  module LineCapStyle
    BUTT = 0
    ROUND = 1
    SQUARE = 2
  end

  module LineJoinStyle
    MITER = 0
    ROUND = 1
    BEVEL = 2
  end

  DEFAULT_LINE_WIDTH = 1.0
  DEFAULT_LINE_CAP = LineCapStyle::BUTT
  DEFAULT_LINE_JOIN = LineJoinStyle::MITER
  DEFAULT_MITER_LIMIT = 10.0
  DEFAULT_DASH_PATTERN = [].freeze
  DEFAULT_DASH_PHASE = 0
  DEFAULT_STROKE_COLOR = PdfColor::Gray.new.freeze
  DEFAULT_FILL_COLOR = PdfColor::Gray.new.freeze
  DEFAULT_USE_EVEN_ODD_RULE = false

  class Pen

    def initialize(operations, use_even_odd_rule: DEFAULT_USE_EVEN_ODD_RULE)
      @operations = operations
      @use_even_odd_rule = use_even_odd_rule
    end

    attr_accessor :use_even_odd_rule

    def set_line_width(line_width)
      @operations.push "#{line_width} w"
    end

    def set_line_cap(line_cap)
      @operations.push "#{line_cap} J"
    end

    def set_line_join(line_join)
      @operations.push "#{line_join} j"
    end

    def set_miter_limit(miter_limit)
      @operations.push "#{miter_limit} M"
    end

    def set_dash(dash_pattern, dash_phase)
      @operations.push "[#{dash_pattern.join(' ')}] #{dash_phase} d"
    end

    def set_stroke_color(color)
      @operations.push color.stroke_color_operation
    end

    def set_fill_color(color)
      @operations.push color.fill_color_operation
    end

    def stroke(path)
      @operations.push "#{path.to_pen_operand}S"
    end

    def fill(path)
      operation = "#{path.to_pen_operand}f"
      operation += "*" if @use_even_odd_rule
      @operations.push operation
    end

    def stroke_fill(path)
      operation = "#{path.to_pen_operand}B"
      operation += "*" if @use_even_odd_rule
      @operations.push operation
    end

  end

  def initialize
    @line_width = DEFAULT_LINE_WIDTH
    @line_cap = DEFAULT_LINE_CAP
    @line_join = DEFAULT_LINE_JOIN
    @miter_limit = DEFAULT_MITER_LIMIT
    @dash_pattern = DEFAULT_DASH_PATTERN
    @dash_phase = DEFAULT_DASH_PHASE
    @stroke_color = DEFAULT_STROKE_COLOR
    @fill_color = DEFAULT_FILL_COLOR
    @use_even_odd_rule = DEFAULT_USE_EVEN_ODD_RULE
  end

  attr_accessor :line_width, :line_cap, :line_join, :miter_limit, :dash_pattern, :dash_phase
  attr_accessor :stroke_color, :fill_color, :use_even_odd_rule

  def draw_on(content, &block)
    content.stack_graphic_state do
      pen = Pen.new(content.operations, use_even_odd_rule: @use_even_odd_rule)

      pen.set_line_width(@line_width) if @line_width != DEFAULT_LINE_WIDTH
      pen.set_line_cap(@line_cap) if @line_cap != DEFAULT_LINE_CAP
      pen.set_line_join(@line_join) if @line_join != DEFAULT_LINE_JOIN
      pen.set_miter_limit(@miter_limit) if @miter_limit != DEFAULT_MITER_LIMIT
      pen.set_dash(@dash_pattern, @dash_phase) if @dash_pattern != DEFAULT_DASH_PATTERN
      pen.set_stroke_color(@stroke_color) if @stroke_color != DEFAULT_STROKE_COLOR
      pen.set_fill_color(@fill_color) if @fill_color != DEFAULT_FILL_COLOR

      block.call(pen)
    end
  end

end

if __FILE__ == $0
  require_relative 'pdf_page'
  require_relative 'pdf_object_binder'

  page_content = PdfPage::Content.new

  path = PdfGraphic::Path.new do
    from [0, 0]
    to [1, 1]
    to [2, 0], ctrl1: [1.552, 1], ctrl2: [2, 0.448]
  end

  graphic = PdfGraphic.new
  graphic.draw_on(page_content) do |pen|
    pen.stroke path
  end

  graphic.draw_on(page_content) do |pen|
    copied = path.clone
    copied.scale ratio: 1.5
    pen.stroke copied
  end

  graphic.line_width = 5
  graphic.line_cap = PdfGraphic::LineCapStyle::ROUND
  graphic.line_join = PdfGraphic::LineJoinStyle::ROUND
  graphic.draw_on(page_content) do |pen|
    copied = path.clone
    copied.move dx: 1, dy: 2
    pen.stroke copied
  end

  graphic.line_cap = PdfGraphic::DEFAULT_LINE_CAP
  graphic.line_join = PdfGraphic::DEFAULT_LINE_JOIN
  graphic.dash_pattern = [4, 2]
  graphic.dash_phase = 2
  graphic.draw_on(page_content) do |pen|
    copied = path.clone
    copied.rotate rad: Math::PI/4, anchor: [1, 1]
    pen.stroke copied
  end

  graphic.dash_pattern = PdfGraphic::DEFAULT_DASH_PATTERN
  graphic.dash_phase = PdfGraphic::DEFAULT_DASH_PHASE
  graphic.stroke_color = PdfColor::Rgb.new red: 1.0
  graphic.fill_color = PdfColor::Rgb.new green: 1.0
  graphic.draw_on(page_content) do |pen|
    copied = path.clone
    copied.h_flip x: 4
    pen.stroke_fill copied
  end

  graphic.use_even_odd_rule = true
  graphic.draw_on(page_content) do |pen|
    copied = path.clone
    copied.v_flip y: 4
    pen.stroke_fill copied
  end

  graphic = PdfGraphic.new
  graphic.draw_on(page_content) do |pen|
    basic_rect = PdfGraphic::Rectangle.new([0, 0], [2, 3])
    pen.stroke basic_rect

    round_rect = PdfGraphic::Rectangle.new([3, 0], [7, 3], round: 1)
    pen.stroke round_rect

    circle = PdfGraphic::Oval.new([0, 0], [1, 1])
    pen.stroke circle

    oval = PdfGraphic::Oval.new([1, 1], [3, 2])
    pen.stroke oval
  end

  binder = PdfObjectBinder.new
  page_content.attach_to(binder)

  binder.serialized_objects.each do |serialized_object|
    puts serialized_object
  end
end
