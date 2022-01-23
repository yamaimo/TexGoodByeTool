# IOを拡張しフォントファイルの各データ型の読み出しを可能にする

module FontDataExtension

  refine IO do

    # 整数（符号あり） ----------

    def read_int8
      self.read(1).unpack('c').first
    end

    def read_int16
      # ネットオーダーバイト列 -> uint16
      # -> ホストオーダーバイト列 -> int16
      self.read(2).unpack('n').pack('s').unpack('s').first
    end

    def read_int32
      # ネットオーダーバイト列 -> uint32
      # -> ホストオーダーバイト列 -> int32
      self.read(4).unpack('N').pack('l').unpack('l').first
    end

    # 整数（符号なし） ----------

    def read_uint8
      self.read(1).unpack('C').first
    end

    def read_uint16
      self.read(2).unpack('n').first
    end

    def read_uint32
      self.read(4).unpack('N').first
    end

    # 識別子 ----------

    def read_tag
      self.read(4)
    end

    # 文字列 ----------

    def read_string(length, encoding = nil)
      self.read(length).encode(Encoding.default_external, encoding)
    end

    # オフセット ----------

    def read_offset16
      self.read_uint16
    end

    def read_offset32
      self.read_uint32
    end

    # フォントデザイン単位 ----------

    def read_fword
      self.read_int16
    end

    def read_ufword
      self.read_uint16
    end

    # 時刻 ----------

    def read_datetime
      upper = self.read_int32
      lower = self.read_uint32
      offset = (upper << 32) | lower
      base = Time.utc(1904)
      base + offset
    end

    # 実数 ----------

    def read_fixed16d16
      int = self.read_int16
      frac = self.read_uint16.to_r
      while frac >= 1
        frac /= 10
      end
      if int < 0
        frac *= -1
      end
      (int + frac).to_f
    end

    def read_fixed2d14
      value = self.read_int16
      int = value >> 14
      frac = (value & 0x3FFF).to_r
      while frac >= 1
        frac /= 10
      end
      if int < 0
        frac *= -1
      end
      (int + frac).to_f
    end

    def read_version16d16
      major = self.read_uint16
      minor = self.read_uint16 / 0x1000
      major + minor / 10.0
    end

  end

end

if __FILE__ == $0
  require 'stringio'
  require 'forwardable'

  def green(str)
    "\x1b[32m#{str}\x1b[0m"
  end

  def red(str)
    "\x1b[31m#{str}\x1b[0m"
  end

  def assert(title, actual, expected)
    if actual == expected
      puts "#{green('[OK]')} #{title}"
    else
      puts "#{red('[NG]')} #{title} (actual: #{actual}, expected: #{expected})"
    end
  end

  # StringIOでrefinementを使えるようにする
  class IoWrapper < IO

    extend Forwardable

    def initialize(io)
      @io = io
    end

    def_delegators :@io, :read

  end

  stringio = StringIO.new(<<~END_OF_FILE)
    \x01\xfe\
    \x00\x01\xff\xfe\
    \x00\x00\x00\x01\xff\xff\xff\xfe\
    \x01\xfe\
    \x00\x01\xff\xfe\
    \x00\x00\x00\x01\xff\xff\xff\xfe\
    ABCD\
    あいうえお\
    \x00\x01\xff\xfe\
    \x00\x00\x00\x01\xff\xff\xff\xfe\
    \x00\x01\xff\xfe\
    \x00\x01\xff\xfe\
    \x01\x23\x45\x67\x89\xab\xcd\xef\
    \x00\x01\x00\x02\xff\xfe\x00\x01\
    \x00\x01\x00\x00\
    \x00\x02\x50\x00
  END_OF_FILE

  file = IoWrapper.new(stringio)

  using FontDataExtension

  assert("read_int8 0x01", file.read_int8, 1)
  assert("read_int8 0xfe", file.read_int8, -2)
  assert("read_int16 0x0001", file.read_int16, 1)
  assert("read_int16 0xfffe", file.read_int16, -2)
  assert("read_int32 0x00000001", file.read_int32, 1)
  assert("read_int32 0xfffffffe", file.read_int32, -2)

  assert("read_uint8 0x01", file.read_uint8, 1)
  assert("read_uint8 0xfe", file.read_uint8, 254)
  assert("read_uint16 0x0001", file.read_uint16, 1)
  assert("read_uint16 0xfffe", file.read_uint16, 65534)
  assert("read_uint32 0x00000001", file.read_uint32, 1)
  assert("read_uint32 0xfffffffe", file.read_uint32, 4294967294)

  assert('read_tag "ABCD"', file.read_tag, "ABCD")

  assert('read_string "あいうえお"', file.read_string(15, 'UTF-8'), "あいうえお")

  assert("read_offset16 0x0001", file.read_offset16, 1)
  assert("read_offset16 0xfffe", file.read_offset16, 65534)
  assert("read_offset32 0x00000001", file.read_offset32, 1)
  assert("read_offset32 0xfffffffe", file.read_offset32, 4294967294)

  assert("read_fword 0x0001", file.read_fword, 1)
  assert("read_fword 0xfffe", file.read_fword, -2)
  assert("read_ufword 0x0001", file.read_ufword, 1)
  assert("read_ufword 0xfffe", file.read_ufword, 65534)

  assert("read_datetime 0x0123456789abcdef", file.read_datetime, Time.utc(1904) + 0x0123456789abcdef)

  assert("read_fixed16d16 0x00010002", file.read_fixed16d16, 1.2)
  assert("read_fixed16d16 0xfffe0001", file.read_fixed16d16, -2.1)

  assert("read_version16d16 0x00010000", file.read_version16d16, 1.0)
  assert("read_version16d16 0x00025000", file.read_version16d16, 2.5)
end
