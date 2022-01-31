# PDFテキスト

require_relative 'hex_extension'

class PdfText

  using HexExtension

  def initialize(resource, operations)
    @resource = resource
    @operations = operations
    @font = nil
  end

  # カーソルを行頭に戻す
  # dx, dyが指定されていた場合、指定された分だけ行頭の位置を変更する
  def return_cursor(dx: 0, dy: 0)
    @operations.push "  #{dx} #{dy} Td"
  end

  def set_font(id, size)
    @operations.push "  /#{id} #{size} Tf"
    @font = @resource.get_font(id)
  end

  def set_leading(size)
    @operations.push "  #{size} TL"
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
