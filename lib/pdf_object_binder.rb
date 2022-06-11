# PDFオブジェクトバインダー
# 各PDFオブジェクトはattach_to(binder)を実装し、binderにオブジェクトを結びつける

require_relative 'pdf_serialize_extension'

class PdfObjectBinder

  using PdfSerializeExtension

  class ObjectRef

    def initialize(id)
      @id = id
    end

    def serialize
      "#{@id} 0 R"
    end

  end

  def initialize
    @id = {}
    @serialized_object = {}
  end

  def get_ref(object)
    if object
      id = get_id(object)
      ObjectRef.new(id)
    else
      nil
    end
  end

  def attach(object, data, stream_data=nil)
    serialized_data = data.serialize
    if stream_data
      serialized_data = <<~END_OF_SERIALIZED_DATA
        #{serialized_data.chomp}
        stream
        #{stream_data.chomp}
        endstream
      END_OF_SERIALIZED_DATA
    end

    id = get_id(object)
    @serialized_object[id] ||= <<~END_OF_SERIALIZED_OBJECT
      #{id} 0 obj
      #{serialized_data.chomp}
      endobj
    END_OF_SERIALIZED_OBJECT
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
      @content = nil
    end

    attr_writer :parent, :content

    def add_child(child)
      @children.push child
      child.parent = self
    end

    def attach_to(binder)
      @children.each {|child| child.attach_to(binder) }

      parent_ref = binder.get_ref(@parent)
      children_ref = @children.map{|child| binder.get_ref(child)}
      dict = {
        Parent: parent_ref,
        Children: children_ref,
      }
      binder.attach(self, dict, @content)
    end

  end

  root = TreeNode.new
  node1 = TreeNode.new
  node2 = TreeNode.new
  root.add_child(node1)
  root.add_child(node2)
  node1_1 = TreeNode.new
  node1.add_child(node1_1)
  node1_1.content = <<~END_OF_CONTENT
    hoge
    huga
  END_OF_CONTENT

  binder = PdfObjectBinder.new
  root.attach_to(binder)

  binder.serialized_objects.each do |serialized_object|
    puts serialized_object
  end
end
