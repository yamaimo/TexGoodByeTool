# PDFページ

require_relative 'hex_extension'

class PdfPage

  class Content

    class Text

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

    def initialize(resource)
      @resource = resource
      @operations = []
    end

    def stack_origin(&block)
      @operations.push "q"
      block.call
      @operations.push "Q"
    end

    def move_origin(x, y)
      @operations.push "1. 0. 0. 1. #{x} #{y} cm"
    end

    def add_text(&block)
      @operations.push "BT"

      text = Text.new(@resource, @operations)
      block.call(text)

      @operations.push "ET"
    end

    def attach_content_to(pool)
      stream = @operations.join("\n")
      length = stream.bytesize + "\n".bytesize

      pool.attach_content(self, <<~END_OF_CONTENT)
        <<
          /Length #{length}
        >>
        stream
        #{stream}
        endstream
      END_OF_CONTENT
    end

  end

  def self.add_to(document)
    page = PdfPage.new
    document.add_page(page)
    page
  end

  def initialize
    @parent = nil
    @content = nil
  end

  def parent=(parent)
    @parent = parent
    @content = Content.new(@parent.resource)
  end

  def add_content(&block)
    block.call(@content)
  end

  def attach_content_to(pool)
    @content.attach_content_to(pool)

    pool.attach_content(self, <<~END_OF_PAGE)
      <<
        /Type /Page
        /Parent #{pool.get_ref(@parent)}
        /Contents [#{pool.get_ref(@content)}]
      >>
    END_OF_PAGE
  end

end

if __FILE__ == $0
  require_relative 'sfnt_font'
  require_relative 'pdf_font'
  require_relative 'length_extension'
  require_relative 'pdf_object_pool'

  if ARGV.empty?
    puts "[Font file list] ----------"
    puts SfntFont.list
    puts "---------------------------"
    raise "No font file is specified."
  end

  filename = ARGV[0]
  sfnt_font = SfntFont.load(filename)
  pdf_font = PdfFont.new(sfnt_font)

  class PdfDocumentMock

    def initialize
      @pages = []
      @resource = {}
      def @resource.add_font(pdf_font)
        self[pdf_font.id] = pdf_font
      end
      def @resource.get_font(id)
        self[id]
      end
    end

    attr_reader :resource

    def add_page(page)
      @pages.push page
      page.parent = self
    end

    def add_font(pdf_font)
      @resource.add_font(pdf_font)
    end

    def attach_content_to(pool)
      @pages.each{|page| page.attach_content_to(pool)}

      pool.attach_content(self, <<~END_OF_DOCUMENT)
        <<
          /Type /Document
        >>
      END_OF_DOCUMENT
    end

  end

  using LengthExtension

  document = PdfDocumentMock.new
  document.add_font(pdf_font)

  page = PdfPage.add_to(document)
  page.add_content do |content|
    content.move_origin 22.mm, 188.mm
    content.add_text do |text|
      text.set_font pdf_font.id, 14
      text.set_leading 16
      ["ABCDE", "あいうえお", "斉斎齊齋", "\u{20B9F}\u{20D45}\u{20E6D}"].each do |str|
        text.puts str
      end
      text.puts
      text.puts "TeXグッバイしたい！"
    end
  end

  pool = PdfObjectPool.new
  document.attach_content_to(pool)

  pool.contents.each do |content|
    puts content
  end
end
