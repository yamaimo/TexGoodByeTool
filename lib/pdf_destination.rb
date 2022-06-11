# PDFデスティネーション

class PdfDestination

  def initialize(page, x, y)
    @page = page
    @x = x
    @y = y
  end

  def to_a(binder)
    [binder.get_ref(@page), :XYZ, @x, @y, nil]
  end

end

if __FILE__ == $0
  require_relative 'pdf_serialize_extension'
  require_relative 'pdf_object_binder'

  using PdfSerializeExtension

  binder = PdfObjectBinder.new
  page = Object.new # dummy

  dest = PdfDestination.new(page, 100, 200)
  puts dest.to_a(binder).serialize
end
