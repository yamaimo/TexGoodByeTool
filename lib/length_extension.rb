# 長さの単位を拡張する

module LengthExtension

  refine Numeric do

    # mm -> ptへの変換
    def mm
      # 1in = 25.4mm, 1in = 72pt
      # よって、25.4 [mm/in], 72 [pt/in]なので、72 / 25.4 [pt/mm]
      self * (72 / 25.4)
    end

    def cm
      self.mm * 10
    end

    def pt
      self
    end

  end

end
