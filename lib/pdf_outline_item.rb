# PDFアウトライン項目

class PdfOutlineItem

  def self.add_to(parent, title, destination_name)
    new_item = PdfOutlineItem.new(title, destination_name)
    parent.add_outline_item(new_item)
    new_item
  end

  def initialize(title, destination_name)
    # destination_nameはエンコードが必要な文字が含まれていないこと
    # （あとで修正したい）
    @title = title
    @destination_name = destination_name
    @children = []

    # 以下はadd_outline_itemで親がセットする
    # ただし、prev, nextは存在しない場合nilのまま
    @parent = nil
    @prev = nil
    @next = nil
  end

  attr_writer :parent, :prev, :next

  def add_outline_item(pdf_outline_item)
    prev_item = nil
    unless @children.empty?
      prev_item = @children[-1]
      prev_item.next = pdf_outline_item
    end

    pdf_outline_item.parent = self
    pdf_outline_item.prev = prev_item

    @children.push pdf_outline_item
  end

  def attach_to(binder)
    @children.each do |child|
      child.attach_to(binder)
    end

    # FIXME: PDF用の基本型を作った方がよさそう
    children_info = ""
    unless @children.empty?
      first_item = @children[0]
      last_item = @children[-1]
      children_info += "  /First #{binder.get_ref(first_item)}\n"
      children_info += "  /Last #{binder.get_ref(last_item)}\n"
      children_info += "  /Count 0\n"
    end

    bros_info = ""
    bros_info += "  /Prev #{binder.get_ref(@prev)}\n" if @prev
    bros_info += "  /Next #{binder.get_ref(@next)}\n" if @next

    binder.attach(self, <<~END_OF_OUTLINE_ITEM)
      <<
        /Title (#{@title})
        /Dest /#{@destination_name}
        /Parent #{binder.get_ref(@parent)}
      #{children_info}#{bros_info}>>
    END_OF_OUTLINE_ITEM
  end

end

if __FILE__ == $0
  require_relative 'pdf_object_binder'

  pdf_document = Object.new # dummy

  root = PdfOutlineItem.new("toc", "toc")
  root.parent = pdf_document

  chap1 = PdfOutlineItem.add_to(root, "chapter 1", "chap1")
  chap2 = PdfOutlineItem.add_to(root, "chapter 2", "chap2")

  sec1_1 = PdfOutlineItem.add_to(chap1, "section 1.1", "sec1_1")
  sec1_2 = PdfOutlineItem.add_to(chap1, "section 1.2", "sec1_2")
  sec1_3 = PdfOutlineItem.add_to(chap1, "section 1.3", "sec1_3")

  sec2_1 = PdfOutlineItem.add_to(chap2, "section 2.1", "sec2_1")
  sec2_2 = PdfOutlineItem.add_to(chap2, "section 2.2", "sec2_2")

  sec2_1_1 = PdfOutlineItem.add_to(sec2_1, "section 2.1.1", "sec2_1_1")
  sec2_1_2 = PdfOutlineItem.add_to(sec2_1, "section 2.1.2", "sec2_1_2")
  sec2_1_3 = PdfOutlineItem.add_to(sec2_1, "section 2.1.3", "sec2_1_3")

  binder = PdfObjectBinder.new
  root.attach_to(binder)

  binder.serialized_objects.each do |serialized_object|
    puts serialized_object
  end
end
