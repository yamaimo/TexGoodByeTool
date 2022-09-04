# PDF画像

require 'chunky_png'
require 'stringio'
require 'zlib'

require_relative 'pdf_serialize_extension'

module PdfImage

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

    def attach_to(binder)
      image = ChunkyPNG::Image.from_file(@path)

      mask_stream = get_mask_stream(image)
      mask_compressed = Zlib::Deflate.deflate(mask_stream)

      rgb_stream = image.to_rgb_stream
      rgb_compressed = Zlib::Deflate.deflate(rgb_stream)

      image_mask = Object.new
      mask_dict = {
        Type: :XObject,
        Subtype: :Image,
        Width: @width,
        Height: @height,
        ImageMask: true,
        BitsPerComponent: 1,
        Filter: :FlateDecode,
        Length: mask_compressed.bytesize,
      }
      binder.attach(image_mask, mask_dict, mask_compressed)

      image_dict = {
        Type: :XObject,
        Subtype: :Image,
        Width: @width,
        Height: @height,
        ColorSpace: :DeviceRGB,
        BitsPerComponent: 8,
        Mask: binder.get_ref(image_mask),
        Filter: :FlateDecode,
        Length: rgb_compressed.bytesize,
      }
      binder.attach(self, image_dict, rgb_compressed)
    end

    private

    def get_mask_stream(image)
      masks = []
      alpha_stream = StringIO.new(image.to_alpha_channel_stream)

      # 行ごとに処理する
      image.height.times do
        line = alpha_stream.read(image.width)
        # 8バイトをパックして1バイトにする（上位ビットから詰める）
        # 足りない場合は下位にパディング
        line.each_byte.each_slice(8) do |data|
          mask = 0
          data.each_with_index do |byte, idx|
            bit = (byte > 0) ? 0 : 1
            mask |= bit << (7 - idx)
          end
          masks.push mask
        end
      end

      masks.pack("C*")
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

    using PdfSerializeExtension

    def initialize(content, anchor: DEFAULT_ANCHOR, dpi: nil)
      @content = content
      @anchor = anchor
      @dpi = dpi
    end

    def paint(image, x: 0, y: 0)
      @content.stack_graphic_state do
        # 画像を出力すると、1pt x 1ptの矩形に出力される
        # 1pt = 1/72inなので、72dpi(=72px/in)のとき1px = 1/72in = 1pt
        # なので72dpiならwidth x heightに伸ばすといい
        # 解像度が違う場合はさらに72/dpi倍すると長さがあう
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

        @content.add_operation "#{x_scale} 0. 0. #{y_scale} #{x} #{y} cm"
        @content.add_operation "#{image.id.to_sym.serialize} Do"
      end
    end

  end

  class Setting

    def initialize
      @anchor = DEFAULT_ANCHOR
      @dpi = DEFAULT_DPI
    end

    attr_accessor :anchor, :dpi

    def get_pen_for(content, &block)
      pen = Pen.new(content, anchor: @anchor, dpi: @dpi)
      block.call(pen)
    end

  end

end

if __FILE__ == $0
  require_relative 'pdf_page'
  require_relative 'pdf_object_binder'

  content = PdfPage::Content.new

  png = PdfImage::Png.load('christmas_snowman.png')
  puts "path: #{png.path}"
  puts "id  : #{png.id}"
  puts "width : #{png.width}"
  puts "height: #{png.height}"
  puts "dpi   : #{png.dpi}"

  image_setting = PdfImage::Setting.new
  image_setting.get_pen_for(content) do |pen|
    pen.paint png
  end

  binder = PdfObjectBinder.new
  png.attach_to(binder)
  content.attach_to(binder)

  binder.serialized_objects.each do |serialized_object|
    puts serialized_object
  end
end
