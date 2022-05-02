# テキストの処理

class TextHandler

  HANGING_CHARS = ")]}>,.;:!?）」』、。；：！？ぁぃぅぇぉっゃゅょァィゥェォッャュョ"

  def self.add_to(dom_handler)
    handler = self.new(dom_handler)
    dom_handler.register_text_handler(handler)
    handler
  end

  def initialize(dom_handler)
    @dom_handler = dom_handler
  end

  def handle_text(text, typeset_document, ignore_line_feed)
    font = @dom_handler.current_font
    text.each_char do |char|
      if (char == "\n") && ignore_line_feed
        next
      end

      page = typeset_document.current_page
      box = page.current_box
      line = box.current_line

      if char != "\n"
        line.push font.get_typeset_char(char)
      else
        if line.height == 0
          # 高さを確保しておく
          line.push font.get_strut
        end
        line = box.new_line
        line.push font.get_font_set_operation
      end

      # 改行処理
      if line.width > line.allocated_width
        last_char = line.pop
        if HANGING_CHARS.include?(last_char.to_s)
          # 元に戻して改行しない
          # FIXME: 複数文字続く場合、はみ出しが大きくなる
          line.push last_char
        else
          new_line = typeset_document.current_page.current_box.new_line
          new_line.push font.get_font_set_operation
          new_line.push last_char
        end
      end

      # 改ページ処理
      if box.height > box.allocated_height
        last_line = box.pop
        new_page = @dom_handler.create_new_page(typeset_document)
        new_box = new_page.new_box(box.margin, box.padding, box.line_gap)
        new_line = new_box.new_line
        while char = last_line.shift
          new_line.push char
        end
      end
    end
    # FIXME: rescue_font対応はまだ
    # FIXME: 禁則処理とか
    # FIXME: "「"で始まる場合は2分空きにしたり
  end

end

if __FILE__ == $0
  # FIXME: 動作確認のコードを追加すること
end
