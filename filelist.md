vol.1 フォントのはなし
======================

1章 SFNT形式
---------------

- `font_data_extension.rb`
- `table_directory.rb`
    - depend: `font_data_extension`
    - depend: `sfnt_font_type`
- `sfnt_font_type.rb`

2章 メタ情報
---------------

- `head_table.rb`
    - depend: `font_data_extension`
- `stack_pos_extension.rb`
- `name_table.rb`
    - depend: `font_data_extension`
    - depend: `stack_pos_extension`
- `post_table.rb`
    - depend: `font_data_extension`
- `os2_table.rb`
    - depend: `font_data_extension`

3章 マップ情報
---------------

- `cmap_table.rb`
    - depend: `font_data_extension`
    - depend: `stack_pos_extension`

4章 メトリック情報
------------------

- `hhea_table.rb`
    - depend: `font_data_extension`
- `hmtx_table.rb`
    - depend: `font_data_extension`

5章 単一フォント
----------------

- `extname_extension.rb`
- `sfnt_font.rb`
    - depend: `extname_extension`
    - depend: `table_directory`
    - depend: `head_table`
    - depend: `name_table`
    - depend: `post_table`
    - depend: `os2_table`
    - depend: `cmap_table`
    - depend: `hhea_table`
    - depend: `hmtx_table`
- `test_sfnt_font.rb`
    - depend: `sfnt_font`

6章 フォントコレクション
------------------------

- `ttc_header.rb`
    - depend: `font_data_extension`
    - depend: `stack_pos_extension`
    - depend: `table_directory`
    - depend: `name_table`
- `sfnt_font_collection.rb`
    - depend: `extname_extension`
    - depend: `sfnt_font`
    - depend: `ttc_header`
    - depend: `table_directory`
- `test_sfnt_font_collection.rb`
    - depend: `sfnt_font_collection.rb`


vol.2 PDFのはなし
====================

1章 PDF概要
---------------

- `pdf_serialize_extension.rb`
- `pdf_object_binder.rb`
    - depend: `pdf_serialize_extension`

2章 ファイル形式
----------------

- `pdf_writer.rb`
    - depend: `pdf_serialize_extension`
    - depend: `pdf_object_binder`
- `length_extension.rb`
- `hello_pdf.rb`
    - depend: `length_extension`
    - depend: `pdf_writer`

3章 ドキュメントとページ
------------------------

- `pdf_document.rb`
- `pdf_page.rb`

4章 グラフィックス
------------------

- `identifiable.rb`
- `pdf_color.rb`
    - depend: `identifiable`
- `pdf_graphic.rb`
    - depend: `pdf_color`
- `pdf_image.rb`
    - depend: `pdf_serialize_extension`
- `test_pdf_output.rb` (要分割)

5章 フォントとテキスト
----------------------

- `hex_extension.rb`
- `pdf_font.rb`
    - depend: `hex_extension`
- `pdf_text.rb`
    - depend: `hex_extension`
    - depend: `pdf_color`
    - depend: `pdf_serialize_extension`
- `test_pdf_output.rb` (要分割)

6章 アウトラインとリンク
------------------------

- `pdf_destination.rb`
- `pdf_outline_item.rb`
- `pdf_document.rb` (再掲)
- `pdf_page.rb` (再掲)
- `test_pdf_output.rb` (要分割)
    - depend: `pdf_font`
    - depend: `length_extension`
    - depend: `pdf_document`
    - depend: `pdf_page`
    - depend: `pdf_graphic`
    - depend: `pdf_image`
    - depend: `pdf_text`
    - depend: `pdf_destination`
    - depend: `pdf_outline_item`
    - depend: `pdf_writer`


others
====================

- `block_node_handler.rb`
- `block_node_style.rb`
- `dom_handler.rb`
- `inline_node_handler.rb`
- `inline_node_style.rb`
- `macro_processor.rb`
- `markdown_parser.rb`
- `page_handler.rb`
- `page_style.rb`
- `parse_test.rb`
- `setting.rb`
- `setting_dsl.rb`
- `text_handler.rb`
- `typeset_box.rb`
- `typeset_char.rb`
- `typeset_document.rb`
- `typeset_font.rb`
- `typeset_line.rb`
- `typeset_margin.rb`
- `typeset_operation.rb`
- `typeset_padding.rb`
- `typeset_page.rb`
