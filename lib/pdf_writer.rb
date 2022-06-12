# PDF出力

require_relative 'pdf_serialize_extension'
require_relative 'pdf_object_binder'

class PdfWriter

  # ヘッダ
  class Header

    def to_s
      <<~END_OF_HEADER
        %PDF-1.7
        %\x89\xAB\xCD\xEF
      END_OF_HEADER
    end

  end

  # 相互参照テーブル
  class CrossRefTable

    def initialize
      @entry = []
    end

    def size
      @entry.size + 1
    end

    def add_entry(offset)
      @entry.push offset
    end

    def to_s
      ret = ""
      row_format = "%010d %05d %s \n"

      ret += "xref\n"
      ret += "0 #{self.size}\n"
      ret += sprintf row_format, 0, 0xffff, 'f'
      @entry.each do |offset|
        ret += sprintf row_format, offset, 0, 'n'
      end

      ret
    end

  end

  # トレーラ
  class Trailer

    using PdfSerializeExtension

    def initialize(root_ref, info_ref, cross_ref_size, cross_ref_offset)
      @root_ref = root_ref
      @info_ref = info_ref
      @cross_ref_size = cross_ref_size
      @cross_ref_offset = cross_ref_offset
    end

    def to_s
      trailer_dict = {
        Root: @root_ref,
        Info: @info_ref,
        Size: @cross_ref_size,
      }
      <<~END_OF_TRAILER
        trailer
        #{trailer_dict.serialize}
        startxref
        #{@cross_ref_offset}
        %%EOF
      END_OF_TRAILER
    end

  end

  def initialize(filepath)
    @filepath = filepath
  end

  def write(document)
    File.open(@filepath, 'w') do |file|
      header = Header.new
      file.puts header

      binder = PdfObjectBinder.new
      document.root.attach_to(binder)
      document.info.attach_to(binder)

      cross_ref_table = CrossRefTable.new
      binder.serialized_objects.each do |serialized_object|
        cross_ref_table.add_entry(file.pos)
        file.puts serialized_object
      end

      cross_ref_offset = file.pos
      file.puts cross_ref_table

      root_ref = binder.get_ref(document.root)
      info_ref = binder.get_ref(document.info)
      cross_ref_size = cross_ref_table.size
      trailer = Trailer.new(root_ref, info_ref, cross_ref_size, cross_ref_offset)
      file.puts trailer
    end
  end

end

if __FILE__ == $0
  class PdfDocumentMock
    class Node
      def attach_to(binder)
        binder.attach(self, {})
      end
    end

    class Root
      def attach_to(binder)
        node = Node.new
        node.attach_to(binder)
        binder.attach(self, {Child: binder.get_ref(node)})
      end
    end

    def initialize
      @root = Root.new
      @info = Node.new
    end

    attr_reader :root, :info
  end

  document = PdfDocumentMock.new

  writer = PdfWriter.new("writer_test.pdf")
  writer.write(document)
end
