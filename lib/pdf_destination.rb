# PDFデスティネーション

class PdfDestination

  def initialize(page, x, y)
    @page = page
    @x = x
    @y = y
  end

  def to_serialized_data(binder)
    "[#{binder.get_ref(@page)} /XYZ #{@x} #{@y} null]"
  end

end

if __FILE__ == $0
  require_relative 'pdf_object_binder'

  binder = PdfObjectBinder.new
  page = Object.new # dummy

  dest = PdfDestination.new(page, 100, 200)
  puts dest.to_serialized_data(binder)
end
