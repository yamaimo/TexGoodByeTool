# 組版オブジェクト：スペース

class TypesetSpace
  # FIXME: このコメントを不要にしたい（ちゃんと整理できてない）
  # child: (none)
  # parent: TypesetText
  #   require: -
  #   required: #stretch_count, #width, #width=, #write_with

  def self.new_stretch(font_size, stretch_count=1)
    self.new(font_size, 0, stretch_count)
  end

  def self.new_fix(font_size, width)
    self.new(font_size, width, 0)
  end

  # 高さだけ確保
  def self.new_strut
    self.new(0, 0, 0)
  end

  def initialize(font_size, width, stretch_count)
    @font_size = font_size
    @width = width
    @stretch_count = stretch_count
  end

  attr_reader :stretch_count
  attr_accessor :width

  def stretch?
    @stretch_count > 0
  end

  def strut?
    @font_size == 0
  end

  def write_with(pen)
    if (@font_size != 0) && (@width != 0)
      n_chars = @width / @font_size
      pen.put_space(n_chars)
    end
  end

end

if __FILE__ == $0
  class PenMock
    def put_space(n_chars)
      puts "[put_space] n_chars: #{n_chars}"
    end
  end

  font_size = 14
  stretch = TypesetSpace.new_stretch(font_size)

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
