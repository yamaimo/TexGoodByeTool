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
    # 矩形、角丸もオプションで
    # not yet
  end

  class Oval < Path
    # 楕円
    # not yet
  end

  class Pen

    def initialize(operations, use_even_odd_rule: false)
      @operations = operations
      @use_even_odd_rule = use_even_odd_rule
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
    operations = content.operations
    operations.push "q"

    operations.push "#{@line_width} w" if @line_width != DEFAULT_LINE_WIDTH
    operations.push "#{@line_cap} J" if @line_cap != DEFAULT_LINE_CAP
    operations.push "#{@line_join} j" if @line_join != DEFAULT_LINE_JOIN
    operations.push "#{@miter_limit} M" if @miter_limit != DEFAULT_MITER_LIMIT
    operations.push "[#{@dash_pattern.join(' ')}] #{@dash_phase} d" if @dash_pattern != DEFAULT_DASH_PATTERN
    operations.push @stroke_color.stroke_color_operation if @stroke_color != DEFAULT_STROKE_COLOR
    operations.push @fill_color.fill_color_operation if @fill_color != DEFAULT_FILL_COLOR

    pen = Pen.new(operations, use_even_odd_rule: @use_even_odd_rule)
    block.call(pen)

    operations.push "Q"
  end

end

if __FILE__ == $0
  require_relative 'pdf_page'
  require_relative 'pdf_object_pool'

  page_content = PdfPage::Content.new(nil)

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

  pool = PdfObjectPool.new
  page_content.attach_content_to(pool)

  pool.contents.each do |content|
    puts content
  end
end
