# ファイルの読み取り位置のスタック可能にする

module StackPosExtension

  refine IO do

    def stack_pos
      org_pos = self.pos
      ret = yield
      self.pos = org_pos

      # ブロックの戻り値を戻す
      ret
    end

  end

end

if __FILE__ == $0
  require 'stringio'
  require 'forwardable'

  # StringIOでrefinementを使えるようにする
  class IoWrapper < IO

    extend Forwardable

    def initialize(io)
      @io = io
    end

    def_delegators :@io, :pos, :pos=, :seek, :read

  end

  stringio = StringIO.new(" " * 100)

  file = IoWrapper.new(stringio)

  using StackPosExtension

  file.read(4)
  puts "[IN 0] pos: #{file.pos}"  # => 4
  file.stack_pos do
    file.seek(10)
    file.read(4)
    puts "  [IN 1] pos: #{file.pos}"  # => 14
    file.stack_pos do
      file.seek(90)
      file.read(4)
    end
    puts "  [OUT1] pos: #{file.pos}"  # => 14
    file.read(30)
  end
  puts "[OUT0] pos: #{file.pos}" # => 4
end
