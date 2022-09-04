# テキストの処理

require_relative 'typeset_body'
require_relative 'typeset_block'

class TextHandler

  def self.add_to(dom_handler)
    handler = self.new(dom_handler)
    dom_handler.register_text_handler(handler)
    handler
  end

  def initialize(dom_handler)
    @dom_handler = dom_handler
  end

  def handle_text(text_str, parent, document)
    if parent.is_a?(TypesetBody) || parent.is_a?(TypesetBlock)
      parent = parent.current_line
    end
    text = parent.new_text

    text_str.each_char do |char|
      text.add_char(char)
      # 改行してる可能性があるので、最新のテキストを取得する
      text = text.latest
    end
  end

end

if __FILE__ == $0
  # FIXME: 動作確認のコードを追加すること
end
