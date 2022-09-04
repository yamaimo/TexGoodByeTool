# #eql?, #==, #hashを定義する

module Identifiable

  # 必要に応じてオーバーライドすること
  def id_variables
    self.instance_variables
  end

  def id_values
    self.id_variables.map{|v| self.instance_variable_get(v)}
  end

  def eql?(other)
    other.is_a?(self.class) \
      && self.id_values.eql?(other.id_values)
  end

  alias_method :==, :eql?

  def hash
    self.id_values.hash
  end

end

if __FILE__ == $0

  class Test1

    include Identifiable

    def initialize(x, y)
      @x = x
      @y = y
    end

    def to_s
      "{x: #{@x}, y: #{@y}}"
    end

  end

  test1_1 = Test1.new(1, 2)
  test1_2 = Test1.new(1, 3)
  test1_3 = Test1.new(2, 2)
  test1_4 = Test1.new(1, 2)

  puts "#{test1_1} == #{test1_2}: #{test1_1 == test1_2}"
  puts "#{test1_1} == #{test1_3}: #{test1_1 == test1_3}"
  puts "#{test1_1} == #{test1_4}: #{test1_1 == test1_4}"

  class Test2

    include Identifiable

    def initialize(x, y)
      @x = x
      @y = y
    end

    # xだけで同一性判定
    def id_variables
      [:@x]
    end

    def to_s
      "{x: #{@x}} (y: #{@y})"
    end

  end

  test2_1 = Test2.new(1, 2)
  test2_2 = Test2.new(1, 3)
  test2_3 = Test2.new(2, 2)
  test2_4 = Test2.new(1, 2)

  puts "#{test2_1} == #{test2_2}: #{test2_1 == test2_2}"
  puts "#{test2_1} == #{test2_3}: #{test2_1 == test2_3}"
  puts "#{test2_1} == #{test2_4}: #{test2_1 == test2_4}"

  puts "#{test1_1} == #{test2_1}: #{test1_1 == test2_1}"
  puts "#{test1_1} == #{test2_2}: #{test1_1 == test2_2}"
  puts "#{test2_1} == #{test1_1}: #{test2_1 == test1_1}"
  puts "#{test2_1} == #{test1_2}: #{test2_1 == test1_2}"
end
