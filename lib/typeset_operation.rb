# 組版オペレーション

class TypesetOperation

  def initialize(width = 0, ascender = 0, descender = 0, &operation)
    @width = width
    @ascender = ascender
    @descender = descender
    @operation = operation
  end

  attr_reader :width, :ascender, :descender

  def height
    @ascender - @descender
  end

  def write_with(pen)
    @operation.call(pen)
  end

end

if __FILE__ == $0
  operation = TypesetOperation.new do |str|
    puts str
  end

  puts "width    : #{operation.width}"
  puts "height   : #{operation.height}"
  puts "ascender : #{operation.ascender}"
  puts "descender: #{operation.descender}"

  operation.write_with("hoge")
end
