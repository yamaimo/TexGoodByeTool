# 組版オブジェクト：伸縮スペース

class TypesetStretchSpace

  def initialize(font_size)
    @font_size = font_size
    @width = 0
  end

  attr_accessor :width

  def write_with(pen)
    n_chars = @width / @font_size
    pen.put_space(n_chars)
  end

end

if __FILE__ == $0
  class PenMock
    def put_space(n_chars)
      puts "[put_space] n_chars: #{n_chars}"
    end
  end

  font_size = 14
  stretch = TypesetStretchSpace.new(font_size)

  puts "width    : #{stretch.width}"

  pen = PenMock.new
  stretch.write_with(pen)

  puts "---"
  stretch.width = 14
  puts "width    : #{stretch.width}"
  stretch.write_with(pen)

  puts "---"
  stretch.width = 1.5
  puts "width    : #{stretch.width}"
  stretch.write_with(pen)

  puts "---"
  stretch.width = -14  # この場合後ろに進むはず
  puts "width    : #{stretch.width}"
  stretch.write_with(pen)
end
