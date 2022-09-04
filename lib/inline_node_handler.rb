# インライン要素の処理

require_relative 'typeset_body'
require_relative 'typeset_block'

class InlineNodeHandler

  def self.add_to(dom_handler, tag, inline_style, text_style)
    handler = self.new(dom_handler, inline_style, text_style)
    dom_handler.register_node_handler(tag, handler)
    handler
  end

  def initialize(dom_handler, inline_style, text_style)
    @dom_handler = dom_handler
    @inline_style = inline_style
    @text_style = text_style
  end

  def handle_node(inline_node, parent, document)
    if parent.is_a?(TypesetBody) || parent.is_a?(TypesetBlock)
      parent = parent.current_line
    end
    inline = parent.new_inline(@inline_style, @text_style)

    inline_node.each do |child_node|
      @dom_handler.dispatch_node_handling(child_node, inline, document)
      # 改行してる可能性があるので、最新のインラインを取得する
      inline = inline.latest
    end
  end

end

if __FILE__ == $0
  # FIXME: 動作確認のコードを追加すること
end
