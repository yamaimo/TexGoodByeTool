# PDFページ

class PdfPage

  class Content

    def initialize
      @operations = []
    end

    def add_operation(operation)
      @operations.push operation
    end

    def stack_graphic_state(&block)
      self.add_operation "q"
      block.call
      self.add_operation "Q"
    end

    def move_origin(x, y)
      self.add_operation "1. 0. 0. 1. #{x} #{y} cm"
    end

    def attach_to(binder)
      stream = @operations.join("\n")
      length = stream.bytesize + "\n".bytesize

      binder.attach(self, {Length: length}, stream)
    end

  end

  def self.add_to(document)
    page = PdfPage.new
    document.add_page(page)
    page
  end

  def initialize
    @content = Content.new
    @links = []
    # @parentはPdfDocumentではなく
    # PdfDocument::PageTreeなことに注意
    @parent = nil
  end

  def parent=(parent)
    @parent = parent
  end

  def add_content(&block)
    block.call(@content)
  end

  def add_link(pdf_link)
    @links.push pdf_link
  end

  def attach_to(binder)
    @content.attach_to(binder)
    @links.each {|link| link.attach_to(binder)}

    page_dict = {
      Type: :Page,
      Parent: binder.get_ref(@parent),
      Contents: [binder.get_ref(@content)],
      Annots: @links.map{|link| binder.get_ref(link)},
    }
    binder.attach(self, page_dict)
  end

end

if __FILE__ == $0
  require 'uri'

  require_relative 'length_extension'
  require_relative 'pdf_object_binder'
  require_relative 'pdf_internal_link'
  require_relative 'pdf_external_link'
  require_relative 'pdf_destination'

  class PdfDocumentMock

    def initialize
      @pages = []
      @dests = {}
    end

    def add_page(page)
      @pages.push page
      page.parent = self
    end

    def add_destination(name, dest)
      @dests[name] = dest
    end

    def attach_to(binder)
      @pages.each{|page| page.attach_to(binder)}
      @dests.each do |name, dest|
        binder.attach(dest, {Name: name.to_sym, Dest: dest.to_a(binder)})
      end

      binder.attach(self, {Type: :Document})
    end

  end

  using LengthExtension

  document = PdfDocumentMock.new
  page = PdfPage.add_to(document)

  page.add_content do |content|
    content.stack_graphic_state do
      content.move_origin(1, 2)
    end
  end

  page.add_link(
    PdfInternalLink.new(
      "id:ABC",
      [22.mm, 188.mm-14.pt, 22.mm+14.pt*3, 188.mm]))
  page.add_link(
    PdfInternalLink.new(
      "id:あいうえお",
      [22.mm, 188.mm-16.pt-14.pt, 22.mm+14.pt*5, 188.mm-16.pt],
      "あいうえお"))

  page.add_link(PdfExternalLink.new(URI.parse("http://www.hoge.huga"), [1, 2, 3, 4]))
  page.add_link(PdfExternalLink.new(URI.parse("https://www.hoge.huga/a/b/c"), [1, 2, 3, 4], "ほげ"))

  document.add_destination("id:ABC", PdfDestination.new(page, 1, 2))

  binder = PdfObjectBinder.new
  document.attach_to(binder)

  binder.serialized_objects.each do |serialized_object|
    puts serialized_object
  end
end
