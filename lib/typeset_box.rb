# 組版ボックス

require 'forwardable'

require_relative 'typeset_line'
require_relative 'typeset_image_line'
require_relative 'pdf_text'

class TypesetBox

  extend Forwardable

  def initialize(allocated_width, allocated_height, margin, padding, line_gap)
    @allocated_width = allocated_width
    @allocated_height = allocated_height
    @margin = margin
    @padding = padding
    @line_gap = line_gap
    @lines = []
  end

  attr_reader :allocated_width, :allocated_height, :margin, :padding, :line_gap

  def width
    content_width = @lines.map(&:width).max
    @padding.left + content_width + @padding.right
  end

  def height
    content_height = @lines.map(&:height).sum + @line_gap * (@lines.size - 1)
    @padding.top + content_height + @padding.bottom
  end

  def new_line
    allocated_line_width = @allocated_width - @padding.left - @padding.right
    line = TypesetLine.new(allocated_line_width)
    @lines.push line
    line
  end

  def new_image_line(pdf_image)
    image_line = TypesetImageLine.new(pdf_image)
    @lines.push image_line
    image_line
  end

  def current_line
    @lines[-1]
  end

  def_delegators :@lines, :push, :pop, :unshift, :shift, :empty?

  def write_to(content)
    # FIXME: 暫定的にはimage lineは段落に1つのみ
    if (@lines.size == 1) && @lines[0].is_a?(TypesetImageLine)
      @lines[0].write_to content
      return
    end

    # FIXME: PdfTextを作るのはフォントが定まるもっと内側でやるべき
    text = PdfText.new(nil, 0)
    text.write_in(content) do |pen|
      init_ascender = @lines.empty? ? 0 : @lines[0].ascender
      pen.return_cursor(dx: @padding.left, dy: - @padding.top - init_ascender)

      leadings = @lines.each_cons(2).map do |current_line, next_line|
        (- current_line.descender) + @line_gap + next_line.ascender
      end
      leadings.push 0 # 番兵

      @lines.zip(leadings).each do |line, leading|
        pen.set_leading(leading)
        line.write_with(pen)
      end
    end
  end

end

if __FILE__ == $0
  require_relative 'sfnt_font'
  require_relative 'typeset_font'
  require_relative 'typeset_margin'
  require_relative 'typeset_padding'
  require_relative 'pdf_page'
  require_relative 'pdf_object_binder'

  sfnt_font = SfntFont.load('ipaexm.ttf')
  font_size = 14

  typeset_font = TypesetFont.new(sfnt_font, font_size)

  box_width = 200
  box_height = 300
  margin = TypesetMargin.new
  padding = TypesetPadding.new(top: 10, right: 10, bottom: 10, left: 10)
  line_gap = font_size / 2

  box1 = TypesetBox.new(box_width, box_height, margin, padding, line_gap)

  ["ABCDEあいうえお", "ほげほげ", "TeXグッバイしたい！"].each do |chars|
    line = box1.new_line
    line.push typeset_font.get_font_set_operation
    chars.each_char do |char|
      line.push typeset_font.get_typeset_char(char)
    end
  end

  box2 = TypesetBox.new(box_width, box_height, margin, padding, line_gap)
  last_line = box1.pop
  box2.unshift last_line

  puts "[line] allocated width: #{last_line.allocated_width}"
  puts "[line] width          : #{last_line.width}"
  puts "[line] height         : #{last_line.height}"
  puts "[line] ascender       : #{last_line.ascender}"
  puts "[line] descender      : #{last_line.descender}"

  puts "[box1] allocated width : #{box1.allocated_width}"
  puts "[box1] allocated height: #{box1.allocated_height}"
  puts "[box1] width           : #{box1.width}"
  puts "[box1] height          : #{box1.height}"
  puts "[box1] margin          : "\
    "(top: #{box1.margin.top}, right: #{box1.margin.right}, "\
    "bottom: #{box1.margin.bottom}, left: #{box1.margin.left})"
  puts "[box1] padding         : "\
    "(top: #{box1.padding.top}, right: #{box1.padding.right}, "\
    "bottom: #{box1.padding.bottom}, left: #{box1.padding.left})"

  puts "[box2] allocated width : #{box2.allocated_width}"
  puts "[box1] allocated height: #{box1.allocated_height}"
  puts "[box2] width           : #{box2.width}"
  puts "[box2] height          : #{box2.height}"
  puts "[box2] margin          : "\
    "(top: #{box2.margin.top}, right: #{box2.margin.right}, "\
    "bottom: #{box2.margin.bottom}, left: #{box2.margin.left})"
  puts "[box2] padding         : "\
    "(top: #{box2.padding.top}, right: #{box2.padding.right}, "\
    "bottom: #{box2.padding.bottom}, left: #{box2.padding.left})"

  content = PdfPage::Content.new
  box1.write_to(content)
  box2.write_to(content)

  binder = PdfObjectBinder.new
  content.attach_to(binder)

  binder.serialized_objects.each do |serialized_object|
    puts serialized_object
  end
end
