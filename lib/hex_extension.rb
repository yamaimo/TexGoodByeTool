# 16進数文字列へのエンコード

module HexExtension

  refine Integer do

    def to_hex_str
      # 数値 -> 16進文字列(4桁)
      sprintf("%04x", self)
    end

    def to_utf16be_hex_str
      # unicode -> UTF-8文字 -> UTF-16BE文字 -> 16進文字列
      [self].pack("U*").encode("UTF-16BE").unpack("H*").first
    end

  end

end
