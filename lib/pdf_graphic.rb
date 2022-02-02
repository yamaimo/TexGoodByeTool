# PDFグラフィックス

class PdfGraphic

  class Path

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

    def move(dx, dy)
      # not yet
    end

    def rotate(rad, anchor: [0, 0])
      # not yet
    end

    def h_flip(x)
      # not yet
    end

    def v_flip(y)
      # not yet
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

  def initialize
    # not yet
  end

  def draw_on(content, &block)
    pen = Pen.new(content.operations)
    block.call(pen)
  end

end

if __FILE__ == $0
  require_relative 'pdf_page'
  require_relative 'pdf_object_pool'

  page_content = PdfPage::Content.new(nil)
  graphic = PdfGraphic.new

  graphic.draw_on(page_content) do |pen|
    path = PdfGraphic::Path.new do
      from [0, 0]
      to [1, 1]
      to [2, 0], ctrl1: [1.552, 1], ctrl2: [2, 0.448]
    end
    pen.stroke path
  end

  pool = PdfObjectPool.new
  page_content.attach_content_to(pool)

  pool.contents.each do |content|
    puts content
  end
end
