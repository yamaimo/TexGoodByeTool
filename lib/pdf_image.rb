# PDF画像

require 'chunky_png'
require 'zlib'

class PdfImage

  class Png

    def self.load(path)
      data = ChunkyPNG::Datastream.from_file(path)
      header = data.header_chunk
      physical = data.physical_chunk

      width = header.width
      height = header.height

      dpi = nil
      if physical
        dpi ||= physical.dpix rescue nil
        dpi ||= physical.dpiy rescue nil
      end
      dpi ||= 72  # デフォルトは72dpi

      self.new(path, width, height, dpi)
    end

    def initialize(path, width, height, dpi)
      @path = path
      @width = width
      @height = height
      @dpi = dpi
    end

    attr_reader :path, :width, :height, :dpi

    def id
      "Image#{self.object_id}"
    end

    def attach_content_to(pool)
      image = ChunkyPNG::Image.from_file(@path)
      rgb_stream = image.to_rgb_stream

      compressed = Zlib::Deflate.deflate(rgb_stream)
      length = compressed.bytesize

      pool.attach_content(self, <<~END_OF_PNG)
        <<
          /Type /XObject
          /Subtype /Image
          /Width #{@width}
          /Height #{@height}
          /ColorSpace /DeviceRGB
          /BitsPerComponent 8
          /Filter /FlateDecode
          /Length #{length}
        >>
        stream
        #{compressed}
        endstream
      END_OF_PNG
    end

  end

  module Anchor
    UPPER_LEFT = 0
    LOWER_LEFT = 1
    UPPER_RIGHT = 2
    LOWER_RIGHT = 3
    CENTER = 4
  end

  DEFAULT_ANCHOR = Anchor::UPPER_LEFT
  DEFAULT_DPI = nil # 画像のdpiを使用

  class Pen

    def initialize(resource, operations, anchor: DEFAULT_ANCHOR, dpi: nil)
      @resource = resource
      @operations = operations
      @anchor = anchor
      @dpi = dpi
    end

    def paint(id, x: 0, y: 0)
      @operations.push "q"

      # 画像を出力すると、1pt x 1ptの矩形に出力される
      # 1pt = 1/72inなので、72dpi(=72px/in)のとき1px = 1/72in = 1pt
      # なので72dpiならwidth x heightに伸ばすといい
      # 解像度が違う場合はさらに72/dpi倍すると長さがあう
      image = @resource.get_image(id)
      dpi = @dpi || image.dpi # 指定がなければ画像のdpiを使う
      scale = 72.0 / dpi
      x_scale = image.width * scale
      y_scale = image.height * scale

      # 何もしないと画像の左下が起点になる
      # 指定されたanchorになるようにオフセットを乗せる
      x_offset, y_offset = \
        case @anchor
        when Anchor::UPPER_LEFT then [0, -y_scale]
        when Anchor::LOWER_LEFT then [0, 0]
        when Anchor::UPPER_RIGHT then [-x_scale, -yscale]
        when Anchor::LOWER_RIGHT then [-x_scale, 0]
        when Anchor::CENTER then [-x_scale/2.0, -y_scale/2.0]
        end
      x += x_offset
      y += y_offset

      @operations.push "#{x_scale} 0. 0. #{y_scale} #{x} #{y} cm"
      @operations.push "/#{id} Do"

      @operations.push "Q"
    end

  end

  def initialize
    @anchor = DEFAULT_ANCHOR
    @dpi = DEFAULT_DPI
  end

  attr_accessor :anchor, :dpi

  def draw_on(content, &block)
    resource = content.resource
    operations = content.operations
    pen = Pen.new(resource, operations, anchor: @anchor, dpi: @dpi)
    block.call(pen)
  end

end

if __FILE__ == $0
  require_relative 'pdf_page'
  require_relative 'pdf_object_pool'

  class ResourceMock

    def initialize
      @images = {}
    end

    def add_image(pdf_image)
      @images[pdf_image.id] = pdf_image
    end

    def get_image(id)
      @images[id]
    end

  end

  resource = ResourceMock.new
  page_content = PdfPage::Content.new(resource)

  pdf_image = PdfImage::Png.load('christmas_snowman.png')
  puts "path: #{pdf_image.path}"
  puts "id  : #{pdf_image.id}"
  puts "width : #{pdf_image.width}"
  puts "height: #{pdf_image.height}"
  puts "dpi   : #{pdf_image.dpi}"

  resource.add_image(pdf_image)

  image = PdfImage.new
  image.draw_on(page_content) do |pen|
    pen.paint pdf_image.id
  end

  pool = PdfObjectPool.new
  pdf_image.attach_content_to(pool)
  page_content.attach_content_to(pool)

  pool.contents.each do |content|
    puts content
  end
end
