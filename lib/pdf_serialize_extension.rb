# Rubyの型で表現したPDFオブジェクトのシリアライズ

module PdfSerializeExtension

  refine TrueClass do

    def serialize
      "true"
    end

  end

  refine FalseClass do

    def serialize
      "false"
    end

  end

  refine NilClass do

    def serialize
      "null"
    end

  end

  refine Numeric do

    def serialize
      self.to_s
    end

  end

  refine Symbol do

    def serialize
      # エスケープが必要なバイト
      bytes_to_be_escaped = "()<>[]{}/%#".bytes
      bytes_to_be_escaped.concat (0x00..0x20).to_a
      bytes_to_be_escaped.concat (0x7f..0xff).to_a

      encoded = self.to_s.each_byte.map do |byte|
        if bytes_to_be_escaped.include?(byte)
          sprintf("#%02x", byte)
        else
          [byte].pack("c")
        end
      end.join

      "/#{encoded}"
    end

  end

  refine String do

    def serialize
      bom = "feff"
      utf16be_hexstr = self.encode("UTF-16BE").unpack("H*").first
      "<#{bom}#{utf16be_hexstr}>"
    end

  end

  refine Array do

    def serialize
      values = self.each.map(&:serialize).join(" ")
      "[#{values}]"
    end

  end

  refine Hash do

    def serialize
      if self.empty?
        "<<>>"
      else
        pairs = self.each.map do |key, value|
          serialized_key = key.to_sym.serialize
          serialized_value = value.serialize
          "#{serialized_key} #{serialized_value}"
        end.join("\n")
        "<<\n#{pairs}\n>>"
      end
    end

  end

end

if __FILE__ == $0
  using PdfSerializeExtension

  data = {
    a: true,
    b: false,
    c: nil,
    d: 1,
    e: 2.0,
    f: :hoge,
    f1: "()<>[]{}/%#".to_sym,
    f2: " \r\n".to_sym,
    f3: "あいうえお".to_sym,
    g: "hoge",
    g1: "日本語",
    h: [],
    i: [1, 2, 3],
    j: [true, false, nil, 1, 2.0, :hoge, "hoge"],
    k: [[1, 2, 3], [4, [5, 6]]],
    l: {},
    m: {a: "aaa", b: "bbb"},
  }

  puts data.serialize
end
