# PDFカラー（グレースケール、RGB、CMYK）

require_relative 'identifiable'

module PdfColor

  class Gray

    include Identifiable

    def initialize(brightness: 0.0)
      self.brightness = brightness
    end

    def brightness=(brightness)
      @brightness = brightness.clamp(0.0, 1.0)
    end

    attr_reader :brightness

    def stroke_color_operation
      "#{@brightness} G"
    end

    def fill_color_operation
      "#{@brightness} g"
    end

  end

  class Rgb

    include Identifiable

    def self.from_hex(hex)
      red = ((hex >> 16) & 0xff) / 0xff.to_f
      green = ((hex >> 8) & 0xff) / 0xff.to_f
      blue = (hex & 0xff) / 0xff.to_f
      self.new(red: red, green: green, blue: blue)
    end

    def initialize(red: 0.0, green: 0.0, blue: 0.0)
      self.red = red
      self.green = green
      self.blue = blue
    end

    def red=(red)
      @red = red.clamp(0.0, 1.0)
    end

    def green=(green)
      @green = green.clamp(0.0, 1.0)
    end

    def blue=(blue)
      @blue = blue.clamp(0.0, 1.0)
    end

    attr_reader :red, :green, :blue

    def stroke_color_operation
      "#{@red} #{@green} #{@blue} RG"
    end

    def fill_color_operation
      "#{@red} #{@green} #{@blue} rg"
    end

  end

  class Cmyk

    include Identifiable

    def initialize(cyan: 0.0, magenta: 0.0, yellow: 0.0, black: 1.0)
      self.cyan = cyan
      self.magenta = magenta
      self.yellow = yellow
      self.black = black
    end

    def cyan=(cyan)
      @cyan = cyan.clamp(0.0, 1.0)
    end

    def magenta=(magenta)
      @magenta = magenta.clamp(0.0, 1.0)
    end

    def yellow=(yellow)
      @yellow = yellow.clamp(0.0, 1.0)
    end

    def black=(black)
      @black = black.clamp(0.0, 1.0)
    end

    attr_reader :cyan, :magenta, :yellow, :black

    def stroke_color_operation
      "#{@cyan} #{@magenta} #{@yellow} #{@black} K"
    end

    def fill_color_operation
      "#{@cyan} #{@magenta} #{@yellow} #{@black} k"
    end

  end

end

if __FILE__ == $0
  gray = PdfColor::Gray.new
  puts gray.stroke_color_operation
  puts gray.fill_color_operation

  rgb = PdfColor::Rgb.new
  puts rgb.stroke_color_operation
  puts rgb.fill_color_operation

  cmyk = PdfColor::Cmyk.new
  puts cmyk.stroke_color_operation
  puts cmyk.fill_color_operation

  red = PdfColor::Rgb.new red: 1.0
  green = PdfColor::Rgb.new green: 1.0
  blue = PdfColor::Rgb.new blue: 1.0
  puts red.stroke_color_operation
  puts green.stroke_color_operation
  puts blue.stroke_color_operation

  black = PdfColor::Rgb.from_hex(0x000000)
  white = PdfColor::Rgb.from_hex(0xffffff)
  puts black.stroke_color_operation
  puts white.stroke_color_operation

  test = PdfColor::Rgb.new
  test.red = 2
  test.green = -2
  test.blue = 0.5
  puts test.stroke_color_operation
end
