# ブロック要素の処理

class BlockNodeHandler

  def self.add_to(dom_handler, tag, block_style, text_style)
    handler = self.new(dom_handler, block_style, text_style)
    dom_handler.register_node_handler(tag, handler)
    handler
  end

  def initialize(dom_handler, block_style, text_style)
    @dom_handler = dom_handler
    @block_style = block_style
    @text_style = text_style
  end

  def handle_node(block_node, parent, document)
    block = parent.new_block(@block_style, @text_style)

    # 改ページする設定でページの先頭にいない場合、改ページする
    # （ブロックが新しいページにコピーされ、元のブロックは空なので削除される；
    # #break_pageは最後の子をコピーするので、あらかじめ追加しておく必要はある）
    if @block_style.begin_new_page? && (not block.page_top?)
      block = parent.break_page
    end

    block_node.each do |child_node|
      @dom_handler.dispatch_node_handling(child_node, block, document)
      # 改ページしてる可能性があるので、最新のブロックを取得する
      block = block.latest

      # 最後に行が追加された場合、高さを超えている可能性がある
      # その場合は改ページする
      # （最後の子がブロックの場合、高さを超えている可能性はないはず；
      # もし超えていたら、子でも高さを超えているはずなので、
      # そちらで改ページが実行済みになるため）
      if block.height > block.allocated_height
        puts "height: #{block.height}, allocated_height: #{block.allocated_height}" # debug
        block.break_page
        block = block.latest
      end
    end
  end

end

if __FILE__ == $0
  # FIXME: 動作確認のコードを追加すること
end
