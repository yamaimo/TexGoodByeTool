# PDFオブジェクトプール
# 各PDFオブジェクトはattach_content_to(pool)を実装し、poolにコンテンツを結びつける

class PdfObjectPool

  def initialize
    @id = {}
    @content = {}
  end

  def attach_content(obj, content)
    id = get_id(obj)
    @content[id] ||= <<~END_OF_CONTENT
      #{id} 0 obj
      #{content.chomp}
      endobj
    END_OF_CONTENT
  end

  def get_ref(obj)
    "#{get_id(obj)} 0 R"
  end

  def contents
    (1..@id.size).map {|id| @content[id] }
  end

  private

  def get_id(obj)
    @id[obj] ||= @id.size + 1
  end

end

if __FILE__ == $0
  class TreeNode

    def initialize
      @parent = nil
      @children = []
    end

    def set_parent(parent)
      @parent = parent
    end

    def add_child(child)
      @children.push child
      child.set_parent(self)
    end

    def attach_content_to(pool)
      @children.each {|child| child.attach_content_to(pool) }
      pool.attach_content(self, <<~END_OF_CONTENT)
        <<
          /Parent #{@parent.nil? ? "null" : pool.get_ref(@parent)}
          /Children [#{@children.empty? ? "null" : @children.map{|child| pool.get_ref(child)}.join(' ')}]
        >>
      END_OF_CONTENT
    end

  end

  root = TreeNode.new
  node1 = TreeNode.new
  node2 = TreeNode.new
  root.add_child(node1)
  root.add_child(node2)
  node1_1 = TreeNode.new
  node1.add_child(node1_1)

  pool = PdfObjectPool.new
  root.attach_content_to(pool)

  pool.contents.each do |content|
    puts content
  end
end
