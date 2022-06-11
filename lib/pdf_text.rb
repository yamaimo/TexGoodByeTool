# PDFテキスト

require_relative 'hex_extension'
require_relative 'pdf_serialize_extension'

class PdfText

  using HexExtension
  using PdfSerializeExtension

  def initialize(operations)
    @operations = operations
    @font = nil
  end

  # カーソルを行頭に戻す
  # dx, dyが指定されていた場合、指定された分だけ行頭の位置を変更する
  def return_cursor(dx: 0, dy: 0)
    @operations.push "  #{dx} #{dy} Td"
  end

  def set_font(pdf_font, size)
    # NOTE: 今はここでpdf_fontに必要とされる機能がsfnt_fontと等しいので、
    # sfnt_fontも指定可能（本来はpdf_fontのみが指定されるべき）
    @operations.push "  #{pdf_font.id.to_sym.serialize} #{size} Tf"
    @font = pdf_font
  end

  def set_leading(size)
    @operations.push "  #{size} TL"
  end

  def set_text_rise(size)
    @operations.push "  #{size} Ts"
  end

  def puts(str="")
    if str.nil? || str.empty?
      @operations.push "  T*"
    else
      encoded = @font.convert_to_gid(str).map(&:to_hex_str).join
      @operations.push "  <#{encoded}> Tj T*"
    end
  end

  def putc(char: nil, gid: 0)
    if char
      gid = @font.convert_to_gid(char).first
    end
    encoded = gid.to_hex_str
    @operations.push "  <#{encoded}> Tj"
  end

  def put_space(n_chars)
    # 正だと間が狭まり、負だと間が広がる
    width = - n_chars * 1000
    @operations.push "  [#{width}] TJ"
  end

end

if __FILE__ == $0
  # not yet
end
