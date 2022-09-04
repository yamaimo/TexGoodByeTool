# 組版オブジェクト：画像

require_relative 'margin'
require_relative 'padding'
require_relative 'pdf_image'

class TypesetImage
  # child: -
  # parent: TypesetLine | TypesetInline
  #   require: (#break_line, #adjust_stretch_width)  # handlerから使う
  #   required: #margin, #width, #ascender, #descender,
  #             #stretch_count, #stretch_width=, #empty?, #write_to
  # other:
  #   required: (not yet)

  # FIXME: margin, paddingには未対応
  # image_styleもあった方がいい（解像度やアンカーの位置）

  def initialize(pdf_image)
    @image = pdf_image
  end

  def width
    scale = 72 / @image.dpi # 72dpiのとき1px=1pt
    @image.width * scale
  end

  def height
    scale = 72 / @image.dpi # 72dpiのとき1px=1pt
    @image.height * scale
  end

  def ascender
    self.height
  end

  def descender
    0
  end

  def margin
    Margin.zero
  end

  def padding
    Padding.zero
  end

  def stretch_count
    0
  end

  def stretch_width=(width)
    # do nothing
  end

  def empty?
    false
  end

  def write_to(content, upper_left_x, upper_left_y)
    puts "TypesetImage#write_to (x: #{upper_left_x}, y: #{upper_left_y})"  # debug
    image_setting = PdfImage::Setting.new
    image_setting.get_pen_for(content) do |pen|
      pen.paint @image, x: upper_left_x, y: upper_left_y
    end
  end

end

if __FILE__ == $0
  # not yet
end
