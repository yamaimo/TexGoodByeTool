# ページを処理する

require_relative 'typeset_font'

class PageHandler

  def self.add_to(dom_handler, page_style)
    handler = self.new(page_style)
    dom_handler.register_page_handler(handler)
    handler
  end

  def initialize(page_style)
    @style = page_style
  end

  def create_new_page(typeset_document)
    new_page = typeset_document.new_page(@style.margin, @style.padding, @style.to_footer_gap)
    add_page_number(typeset_document)
    new_page
  end

  private

  def add_page_number(typeset_document)
    page_number = typeset_document.page_count
    is_odd_page = page_number % 2 == 1
    page_number_str = page_number.to_s

    footer = typeset_document.current_page.footer
    line = footer.new_line
    font = TypesetFont.new(@style.footer_sfnt_font, @style.footer_font_size)
    # 右揃えできるように、フォント設定は最後に左端に追加する

    page_number_str.each_char do |char|
      line.push font.get_typeset_char(char)
    end

    if is_odd_page
      space = line.allocated_width - line.width
      space_as_char_count = space / @style.footer_font_size
      line.unshift font.get_space(space_as_char_count)
    end
    line.unshift font.get_font_set_operation
  end

end

if __FILE__ == $0
  # FIXME: 動作確認のコードを追加すること
end
