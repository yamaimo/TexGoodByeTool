# PDF内部リンク

class PdfInternalLink

  def initialize(destination_name, rect, alt=nil)
    @destination_name = destination_name
    @rect = rect
    @alt = alt
  end

  def attach_to(binder)
    link_dict = {
      Subtype: :Link,
      Rect: @rect,
      Border: [0, 0, 0],
      Dest: @destination_name.to_sym,
    }
    link_dict[:Contents] = @alt if @alt

    binder.attach(self, link_dict)
  end

end

if __FILE__ == $0
  require_relative 'pdf_object_binder'

  link1 = PdfInternalLink.new("id:ABC", [1, 2, 3, 4])
  link2 = PdfInternalLink.new("id:あいうえお", [1, 2, 3, 4], "あいうえお")

  binder = PdfObjectBinder.new
  link1.attach_to(binder)
  link2.attach_to(binder)

  binder.serialized_objects.each do |serialized_object|
    puts serialized_object
  end
end
