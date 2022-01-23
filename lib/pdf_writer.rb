# PDF出力

require_relative 'pdf_object_pool'

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

    def initialize(root_ref, cross_ref_size, cross_ref_offset)
      @root_ref = root_ref
      @cross_ref_size = cross_ref_size
      @cross_ref_offset = cross_ref_offset
    end

    def to_s
      <<~END_OF_TRAILER
        trailer
        <<
          /Root #{@root_ref}
          /Size #{@cross_ref_size}
        >>
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

      pool = PdfObjectPool.new
      document.root.attach_content_to(pool)

      cross_ref_table = CrossRefTable.new
      pool.contents.each do |content|
        cross_ref_table.add_entry(file.pos)
        file.puts content
      end

      cross_ref_offset = file.pos
      file.puts cross_ref_table

      root_ref = pool.get_ref(document.root)
      cross_ref_size = cross_ref_table.size
      trailer = Trailer.new(root_ref, cross_ref_size, cross_ref_offset)
      file.puts trailer
    end
  end

end

if __FILE__ == $0
  if ARGV.empty?
    raise "No output file is specified."
  end

  filename = ARGV[0]

  class PdfDocumentMock
    class Node
      def attach_content_to(pool)
        pool.attach_content(self, "<< >>")
      end
    end

    class Root
      def attach_content_to(pool)
        node = Node.new
        node.attach_content_to(pool)
        pool.attach_content(self, "<< /Child #{pool.get_ref(node)} >>")
      end
    end

    def initialize
      @root = Root.new
    end

    attr_reader :root
  end

  document = PdfDocumentMock.new

  writer = PdfWriter.new(filename)
  writer.write(document)
end