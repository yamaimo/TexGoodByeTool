# 設定

# ビルド設定

target :sample do
  output "README.pdf"
  sources "README.md"
  macro "macro.rb"
  style :normal
end

default_target :sample

# フォント設定

font :hiramin do
  file "ヒラギノ明朝 ProN.ttc", index: 0
end

font :hiramin_bold do
  file "ヒラギノ明朝 ProN.ttc", index: 2
end

font :ricty do
  file "RictyDiminished-Regular.ttf"
end

# スタイル設定

style :normal do
  document do
    # A5
    paper width: 148.mm, height: 210.mm
    default_font name: :hiramin, size: 9.pt
    default_line_gap 6.pt
  end

  page do
    margin top: 1.5.cm, right: 2.cm, bottom: 1.5.cm, left: 2.cm
    to_footer_gap (0.8.cm - 9.pt)
  end

  block :h1 do
    border bottom: 1.pt
    margin bottom: 20.pt
    padding bottom: 1.pt
    font name: :hiramin_bold, size: 16.pt
  end

  block :h2 do
    border left: 4.pt
    margin top: 20.pt, bottom: 14.pt, left: 2.pt
    padding left: 6.pt
    font name: :hiramin_bold, size: 12.pt
  end

  block :h3 do
    margin top: 16.pt, bottom: 12.pt
    font name: :hiramin_bold, size: 10.pt
  end

  block :p do
    margin top: 7.pt, bottom: 7.pt
  end

  block :pre do
    border top: 0.5.pt, right: 0.5.pt, bottom: 0.5.pt, left: 0.5.pt
    margin top: 15.pt, bottom: 15.pt
    padding top: 3.pt, right: 3.pt, bottom: 3.pt, left: 3.pt
    line_gap 2.pt
  end

  inline :em do
    font name: :hiramin_bold
  end

  inline :strong do
    font name: :hiramin_bold
  end

  inline :code do
    font name: :ricty
  end
end
