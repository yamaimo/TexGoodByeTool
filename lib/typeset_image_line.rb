# 組版での画像の行

# FIXME: 暫定的な実装
# 画像はインライン要素なので文字と同列に扱いたい。
# しかし、今は各文字の行内での座標情報が取れず、
# それを取れるようにしようとするとかなり大変。
# なので、行を画像として扱うようにする。
# 同じ段落で複数画像を出したり、文字を出したりするのは非対応。

require_relative 'pdf_image'

class TypesetImageLine

  def initialize(pdf_image)
    @image = pdf_image
  end

  def width
    scale = 72 / @image.dpi # 72dpiのとき1px=1pt
    @image.width * scale
  end

  def height
    scale = 72 / @image.dpi # 72dpiのとき1px=1pt
    @image.height * scale
  end

  def ascender
    self.height
  end

  def descender
    0
  end

  def write_to(content)
    # NOTE: 呼ばれるときに原点は左上にある
    image = PdfImage.new
    image.write_in(content) do |pen|
      pen.paint @image
    end
  end

end
