# 組版フォント

require_relative 'typeset_operation'
require_relative 'typeset_char'

class TypesetFont

  def initialize(sfnt_font, size)
    @sfnt_font = sfnt_font
    @size = size
  end

  attr_reader :sfnt_font, :size

  def get_font_set_operation
    TypesetOperation.new do |text|
      text.set_font @sfnt_font.id, @size
    end
  end

  def get_typeset_char(char)
    gid = @sfnt_font.convert_to_gid(char).first
    width = @sfnt_font.widths[gid] * @size / 1000.0
    ascender = @sfnt_font.ascender * @size / 1000.0
    descender = @sfnt_font.descender * @size / 1000.0
    TypesetChar.new(char, gid, width, ascender, descender)
  end

  def get_space(n_chars)
    width = @size * n_chars
    TypesetOperation.new(width) do |text|
      text.put_space n_chars
    end
  end

  def get_strut
    ascender = @sfnt_font.ascender * @size / 1000.0
    descender = @sfnt_font.descender * @size / 1000.0
    TypesetOperation.new(0, ascender, descender) {}
  end

end

if __FILE__ == $0
  require_relative 'sfnt_font'

  class TextMock

    def set_font(id, size)
      puts "[set_font] id: #{id}, size: #{size}"
    end

    def putc(char: nil, gid: 0)
      puts "[putc] gid: #{gid}"
    end

    def put_space(n_chars)
      puts "[put_space] n_chars: #{n_chars}"
    end

  end

  sfnt_font = SfntFont.load('ipaexm.ttf')
  font_size = 14

  typeset_font = TypesetFont.new(sfnt_font, font_size)

  line = []
  line.push typeset_font.get_font_set_operation
  line.push typeset_font.get_space(1)
  "ABCDEあいうえお".each_char do |char|
    line.push typeset_font.get_typeset_char(char)
  end

  line_width = line.map(&:width).sum
  line_height = line.map(&:height).max
  puts "line width : #{line_width}"
  puts "line height: #{line_height}"

  text = TextMock.new
  line.each do |item|
    item.write_to(text)
  end
end
