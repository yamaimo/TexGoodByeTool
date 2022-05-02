# インライン要素の処理

class InlineNodeHandler

  def self.add_to(dom_handler, tag, inline_node_style)
    handler = self.new(dom_handler, inline_node_style)
    dom_handler.register_node_handler(tag, handler)
    handler
  end

  def initialize(dom_handler, inline_node_style)
    @dom_handler = dom_handler
    @style = inline_node_style
  end

  def handle_node(inline_node, typeset_document)
    line = document.current_page.current_box.current_line
    prev_font = @dom_handler.current_font
    font = TypesetFont.new(@style.sfnt_font, prev_font.size)
    line.push font.get_font_set_operation

    prev_ignore_line_feed = @dom_handler.ignore_line_feed
    @dom_handler.ignore_line_feed = @style.ignore_line_feed

    @dom_handler.stack_font(font) do
      # inline_nodeの下はstringのみ
      inline_node.each do |string|
        @dom_handler.dispatch_node_handling(string, document)
      end
    end

    @dom_handler.ignore_line_feed = prev_ignore_line_feed

    line = document.current_page.current_box.current_line
    line.push prev_font.get_font_set_operation
  end

end

if __FILE__ == $0
  # FIXME: 動作確認のコードを追加すること
end
