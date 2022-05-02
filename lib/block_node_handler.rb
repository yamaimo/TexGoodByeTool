# ブロック要素の処理

require_relative 'typeset_font'

class BlockNodeHandler

  def self.add_to(dom_handler, tag, block_node_style)
    handler = self.new(dom_handler, block_node_style)
    dom_handler.register_node_handler(tag, handler)
    handler
  end

  def initialize(dom_handler, block_node_style)
    @dom_handler = dom_handler
    @style = block_node_style
  end

  def handle_node(block_node, typeset_document)
    if @style.begin_new_page? && (! typeset_document.current_page.empty?)
      @dom_handler.create_new_page(typeset_document)
    end

    box = typeset_document.current_page.new_box(@style.margin, @style.padding, @style.line_gap)
    line = box.new_line
    font = TypesetFont.new(@style.sfnt_font, @style.font_size)
    line.push font.get_font_set_operation
    if @style.indent != 0
      line.push font.get_space(@style.indent) # 行頭インデント
    end

    @dom_handler.stack_font(font) do
      block_node.each do |child|
        @dom_handler.dispatch_node_handling(child, typeset_document)
      end
    end
  end

end

if __FILE__ == $0
  # FIXME: 動作確認のコードを追加すること
end
