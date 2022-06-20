# 組版ページ

require 'forwardable'

require_relative 'typeset_box'
require_relative 'typeset_margin'
require_relative 'typeset_padding'

class TypesetPage

  extend Forwardable

  def initialize(allocated_width, allocated_height, margin, padding, to_footer_gap)
    @allocated_width = allocated_width
    @allocated_height = allocated_height
    @margin = margin
    @padding = padding
    @boxes = []

    @to_footer_gap = to_footer_gap
    @footer = nil
  end

  attr_reader :allocated_width, :allocated_height, :margin, :padding, :footer

  def width
    content_width = @boxes.map{|box| box.margin.left + box.width + box.margin.right}.max
    @padding.left + content_width + @padding.right
  end

  def height
    # NOTE: 先頭のボックスの上側マージンと最後のボックスの下側マージンは無視
    box_margins = @boxes.each_cons(2).map{|upper, lower| [upper.margin.bottom, lower.margin.top].max}.sum
    content_height = @boxes.map(&:height).sum + box_margins
    @padding.top + content_height + @padding.bottom
  end

  def new_box(margin, padding, line_gap)
    allocated_box_width = @allocated_width - @padding.left - margin.left - margin.right - @padding.right

    current_height = self.height
    between_margin = 0
    if not @boxes.empty?
      # 直前のボックスの下側マージンと追加するボックスの上側マージンで大きい方を使う
      prev_box_bottom_margin = @boxes[-1].margin.bottom
      between_margin = [prev_box_bottom_margin, margin.top].max
    end
    allocated_box_height = @allocated_height - current_height - between_margin

    box = TypesetBox.new(allocated_box_width, allocated_box_height, margin, padding, line_gap)
    @boxes.push box
    box
  end

  def current_box
    @boxes[-1]
  end

  def footer
    if @footer.nil?
      # FIXME: とりあえずの実装
      # フッターは一つのボックスとし、上下マージンは0、左右マージンはページと同じとする
      # そしてto_footer_gapが上パディング
      # 行送りは0
      allocated_footer_width = @allocated_width
      allocated_footer_height = @margin.bottom - @to_footer_gap
      footer_margin = TypesetMargin.new(left: @margin.left, right: @margin.right)
      footer_padding = TypesetPadding.new(top: @to_footer_gap)
      @footer = TypesetBox.new(allocated_footer_width, allocated_footer_height, footer_margin, footer_padding, 0)
    end
    @footer
  end

  def_delegators :@boxes, :push, :pop, :unshift, :shift, :empty?

  def write_to(content)
    upper_left_x = @margin.left
    upper_left_y = @margin.bottom + @allocated_height
    current_y = upper_left_y - @padding.top
    prev_box_margin_bottom = nil
    @boxes.each do |box|
      x = upper_left_x + @padding.left + box.margin.left
      if prev_box_margin_bottom
        vertical_margin = [prev_box_margin_bottom, box.margin.top].max
        current_y -= vertical_margin
      end

      content.stack_graphic_state do
        content.move_origin x, current_y
        box.write_to content
      end

      current_y -= box.height
      prev_box_margin_bottom = box.margin.bottom
    end

    if @footer
      content.move_origin @margin.left, @margin.bottom
      @footer.write_to content
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

  page_width = 200
  page_height = 500
  page_margin = TypesetMargin.new(top: 20, right: 20, bottom: 20, left: 20)
  page_padding = TypesetPadding.new(top: 10, right: 10, bottom: 10, left: 10)
  line_gap = font_size / 2

  page = TypesetPage.new(page_width, page_height, page_margin, page_padding, 0)

  box_margin = TypesetMargin.new
  box_padding = TypesetPadding.new(top: 10, right: 10, bottom: 10, left: 10)

  box1 = page.new_box(box_margin, box_padding, line_gap)

  ["ABCDEあいうえお", "ほげほげ", "TeXグッバイしたい！"].each do |chars|
    line = box1.new_line
    line.push typeset_font.get_font_set_operation
    chars.each_char do |char|
      line.push typeset_font.get_typeset_char(char)
    end
  end
  last_line = box1.pop

  box2 = page.new_box(box_margin, box_padding, line_gap)
  box2.push last_line

  puts "[page] allocated width : #{page.allocated_width}"
  puts "[page] allocated height: #{page.allocated_height}"
  puts "[page] width           : #{page.width}"
  puts "[page] height          : #{page.height}"
  puts "[page] margin          : "\
    "(top: #{page.margin.top}, right: #{page.margin.right}, "\
    "bottom: #{page.margin.bottom}, left: #{page.margin.left})"
  puts "[page] padding         : "\
    "(top: #{page.padding.top}, right: #{page.padding.right}, "\
    "bottom: #{page.padding.bottom}, left: #{page.padding.left})"

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
  puts "[box2] allocated height: #{box2.allocated_height}"
  puts "[box2] width           : #{box2.width}"
  puts "[box2] height          : #{box2.height}"
  puts "[box2] margin          : "\
    "(top: #{box2.margin.top}, right: #{box2.margin.right}, "\
    "bottom: #{box2.margin.bottom}, left: #{box2.margin.left})"
  puts "[box2] padding         : "\
    "(top: #{box2.padding.top}, right: #{box2.padding.right}, "\
    "bottom: #{box2.padding.bottom}, left: #{box2.padding.left})"

  content = PdfPage::Content.new
  page.write_to(content)

  binder = PdfObjectBinder.new
  content.attach_to(binder)

  binder.serialized_objects.each do |serialized_object|
    puts serialized_object
  end
end
