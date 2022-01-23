# 組版ライン

require 'forwardable'

class TypesetLine

  extend Forwardable

  def initialize(allocated_width = 0)
    @allocated_width = allocated_width
    @chars = []
  end

  attr_reader :allocated_width

  def width
    @chars.map(&:width).sum
  end

  def height
    self.ascender - self.descender
  end

  def ascender
    @chars.map(&:ascender).max || 0
  end

  def descender
    @chars.map(&:descender).min || 0
  end

  def_delegators :@chars, :push, :pop, :unshift, :shift, :empty?

  def write_to(text)
    @chars.each do |char|
      char.write_to(text)
    end
    text.puts
  end

end

if __FILE__ == $0
  require_relative 'sfnt_font'
  require_relative 'typeset_font'

  class TextMock

    def set_font(id, size)
      STDOUT.puts "[set_font] id: #{id}, size: #{size}"
    end

    def puts(str="")
      STDOUT.puts "[puts]"
    end

    def putc(char: nil, gid: 0)
      STDOUT.puts "[putc] gid: #{gid}"
    end

  end

  sfnt_font = SfntFont.load('ipaexm.ttf')
  font_size = 14

  typeset_font = TypesetFont.new(sfnt_font, font_size)

  line = TypesetLine.new(200)
  line.push typeset_font.get_font_set_operation
  "ABCDEあいうえお".each_char do |char|
    line.push typeset_font.get_typeset_char(char)
  end

  puts "allocated width: #{line.allocated_width}"
  puts "line width     : #{line.width}"
  puts "line height    : #{line.height}"
  puts "line ascender  : #{line.ascender}"
  puts "line descender : #{line.descender}"

  text = TextMock.new
  line.write_to(text)
end
