# PDF外部リンク

class PdfExternalLink

  def initialize(uri, rect, alt=nil)
    @uri = uri
    @rect = rect
    @alt = alt
  end

  def attach_to(binder)
    link_dict = {
      Subtype: :Link,
      Rect: @rect,
      Border: [0, 0, 0],
      A: {S: :URI, URI: @uri},
    }
    link_dict[:Contents] = @alt if @alt

    binder.attach(self, link_dict)
  end

end

if __FILE__ == $0
  require 'uri'

  require_relative 'pdf_object_binder'

  link1 = PdfExternalLink.new(URI.parse("http://www.hoge.huga"), [1, 2, 3, 4])
  link2 = PdfExternalLink.new(URI.parse("https://www.hoge.huga/a/b/c"), [1, 2, 3, 4], "ほげ")

  binder = PdfObjectBinder.new
  link1.attach_to(binder)
  link2.attach_to(binder)

  binder.serialized_objects.each do |serialized_object|
    puts serialized_object
  end
end
