# SFNT形式フォントの種類

class SfntFontType

  def initialize(name)
    @name = name
  end

  def to_s
    @name
  end

  OPEN_TYPE = self.new("OpenType")
  TRUE_TYPE = self.new("TrueType")

end
