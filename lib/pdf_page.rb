# PDFページ

require 'forwardable'

require_relative 'pdf_destination'

class PdfPage

  class Content

    extend Forwardable

    def initialize(document, page)
      @document = document
      @page = page
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

    def add_destination(name, x, y)
      destination = PdfDestination.new(@page, x, y)
      @document.add_destination(name, destination)
    end

    def_delegators :@page, :add_internal_link, :add_external_link

    def attach_to(binder)
      stream = @operations.join("\n")
      length = stream.bytesize + "\n".bytesize

      binder.attach(self, {Length: length}, stream)
    end

  end

  class InternalLink

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

  class ExternalLink

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

  def self.add_to(document)
    page = PdfPage.new(document)
    document.add_page(page)
    page
  end

  def initialize(document)
    @content = Content.new(document, self)
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

  def add_internal_link(destination_name, rect, alt=nil)
    link = InternalLink.new(destination_name, rect, alt)
    @links.push link
  end

  def add_external_link(uri, rect, alt=nil)
    link = ExternalLink.new(uri, rect, alt)
    @links.push link
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
    content.add_internal_link(
      "id:ABC",
      [22.mm, 188.mm-14.pt, 22.mm+14.pt*3, 188.mm])
    content.add_internal_link(
      "id:あいうえお",
      [22.mm, 188.mm-16.pt-14.pt, 22.mm+14.pt*5, 188.mm-16.pt],
      "あいうえお")

    content.add_external_link(
      URI.parse("http://www.hoge.huga"),
      [1, 2, 3, 4])
    content.add_external_link(
      URI.parse("https://www.hoge.huga/a/b/c"),
      [1, 2, 3, 4], "ほげ")

    content.add_destination("id:ABC", 1, 2)
  end

  binder = PdfObjectBinder.new
  document.attach_to(binder)

  binder.serialized_objects.each do |serialized_object|
    puts serialized_object
  end
end
