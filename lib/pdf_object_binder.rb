# PDFオブジェクトバインダー
# 各PDFオブジェクトはattach_to(binder)を実装し、binderにオブジェクトを結びつける

class PdfObjectBinder

  def initialize
    @id = {}
    @serialized_object = {}
  end

  def attach(object, serialized_data)
    id = get_id(object)
    @serialized_object[id] ||= <<~END_OF_SERIALIZED_OBJECT
      #{id} 0 obj
      #{serialized_data.chomp}
      endobj
    END_OF_SERIALIZED_OBJECT
  end

  def get_ref(object)
    "#{get_id(object)} 0 R"
  end

  def serialized_objects
    (1..@id.size).map {|id| @serialized_object[id] }
  end

  private

  def get_id(object)
    @id[object] ||= @id.size + 1
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

    def attach_to(binder)
      @children.each {|child| child.attach_to(binder) }
      binder.attach(self, <<~END_OF_SERIALIZED_DATA)
        <<
          /Parent #{@parent.nil? ? "null" : binder.get_ref(@parent)}
          /Children [#{@children.empty? ? "null" : @children.map{|child| binder.get_ref(child)}.join(' ')}]
        >>
      END_OF_SERIALIZED_DATA
    end

  end

  root = TreeNode.new
  node1 = TreeNode.new
  node2 = TreeNode.new
  root.add_child(node1)
  root.add_child(node2)
  node1_1 = TreeNode.new
  node1.add_child(node1_1)

  binder = PdfObjectBinder.new
  root.attach_to(binder)

  binder.serialized_objects.each do |serialized_object|
    puts serialized_object
  end
end
