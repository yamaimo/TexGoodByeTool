# cmapテーブル

require_relative 'font_data_extension'
require_relative 'stack_pos_extension'

class CmapTable

  using FontDataExtension
  using StackPosExtension

  GID_NOT_FOUND = 0

  class Format4Subtable

    class DeltaRecord

      def initialize(start_cid, end_cid, gid_delta)
        @start_cid = start_cid
        @end_cid = end_cid
        @gid_delta = gid_delta
      end

      attr_reader :start_cid, :end_cid

      def get_gid(cid)
        if (@start_cid..@end_cid).include?(cid)
          (cid + @gid_delta) & 0x0000ffff
        else
          CmapTable::GID_NOT_FOUND
        end
      end

    end

    class ArrayRecord

      def initialize(start_cid, end_cid, gid_array)
        @start_cid = start_cid
        @end_cid = end_cid
        @gid_array = gid_array
      end

      attr_reader :start_cid, :end_cid

      def get_gid(cid)
        if (@start_cid..@end_cid).include?(cid)
          @gid_array[cid - @start_cid]
        else
          CmapTable::GID_NOT_FOUND
        end
      end

    end

    def self.from_file(file, cmap_offset, subtable_offset)
      file.seek(cmap_offset + subtable_offset)

      # format(2byte), length(2byte), language(2byte)はスキップ
      file.seek(6, IO::SEEK_CUR)

      record_count = file.read_uint16 / 2

      # search_range(2byte), entry_selector(2byte),
      # range_shift(2byte)はスキップ
      file.seek(6, IO::SEEK_CUR)

      end_cids = record_count.times.map { file.read_uint16 }
      file.read_uint16  # reserved_pad, 使わない

      start_cids = record_count.times.map { file.read_uint16 }

      gid_deltas = record_count.times.map { file.read_int16 }

      gid_array_offsets = record_count.times.map do
        offset_base = file.pos
        offset = file.read_uint16
        (offset == 0) ? 0 : (offset_base + offset)
      end

      zipped = start_cids.zip(end_cids, gid_deltas, gid_array_offsets)
      zipped.pop  # ターミネータは取り除いておく
      records = zipped.map do |start_cid, end_cid, gid_delta, gid_array_offset|
        if gid_array_offset == 0
          DeltaRecord.new(start_cid, end_cid, gid_delta)
        else
          file.seek(gid_array_offset)
          id_count = (end_cid - start_cid + 1)
          gid_array = id_count.times.map { file.read_uint16 }
          ArrayRecord.new(start_cid, end_cid, gid_array)
        end
      end

      self.new(records)
    end

    def initialize(records)
      @records = records

      # 番兵を追加（Unicode Full対策）
      sentinel = DeltaRecord.new(0x10ffff, 0x10ffff, 1)
      @records.push sentinel
    end

    def find_gid(cid)
      # Array#bsearchでrecord.end_cidが初めてcidを含むrecordを探す
      found_record = @records.bsearch do |record|
        cid <= record.end_cid
      end
      found_record.get_gid(cid)
    end

  end

  class Format12Subtable

    class BaseRecord

      def initialize(start_cid, end_cid, gid_base)
        @start_cid = start_cid
        @end_cid = end_cid
        @gid_base = gid_base
      end

      attr_reader :start_cid, :end_cid

      def get_gid(cid)
        if (@start_cid..@end_cid).include?(cid)
          @gid_base + (cid - @start_cid)
        else
          CmapTable::GID_NOT_FOUND
        end
      end

    end

    def self.from_file(file, cmap_offset, subtable_offset)
      file.seek(cmap_offset + subtable_offset)

      # format(2byte), reserved(2byte),
      # length(4byte), language(4byte)はスキップ
      file.seek(12, IO::SEEK_CUR)

      record_count = file.read_uint32

      records = record_count.times.map do
        start_cid = file.read_uint32
        end_cid = file.read_uint32
        gid_base = file.read_uint32

        BaseRecord.new(start_cid, end_cid, gid_base)
      end

      self.new(records)
    end

    def initialize(records)
      # Array#bsearchのために逆順にしておく（start_cidに関して降順）
      @reversed_records = records.reverse

      # 番兵を追加
      sentinel = BaseRecord.new(0, 0, CmapTable::GID_NOT_FOUND)
      @reversed_records.push sentinel
    end

    def find_gid(cid)
      # Array#bsearchでrecord.start_cidが初めてcid以下になるrecordを探す
      found_record = @reversed_records.bsearch do |record|
        record.start_cid <= cid
      end
      found_record.get_gid(cid)
    end

  end

  def self.from_file(file, cmap_record)
    cmap_offset = cmap_record.offset
    file.seek(cmap_offset)

    # version(2byte)はスキップ
    file.seek(2, IO::SEEK_CUR)

    subtable_count = file.read_uint16

    subtables = {}
    subtable_count.times do
      platform_id = file.read_uint16
      encoding_id = file.read_uint16
      subtable_offset = file.read_offset32

      if not subtables.has_key?(subtable_offset)
        file.stack_pos do
          file.seek(cmap_record.offset + subtable_offset)
          format_id = file.read_uint16

          case [platform_id, encoding_id, format_id]
          when [0, 3, 4], [3, 1, 4] # Unicode BMP
            subtables[subtable_offset] = Format4Subtable.from_file(file, cmap_offset, subtable_offset)
          when [0, 4, 12], [3, 10, 12]  # Unicode Full
            subtables[subtable_offset] = Format12Subtable.from_file(file, cmap_offset, subtable_offset)
          end
        end
      end
    end

    self.new(subtables.values)
  end

  def initialize(subtables)
    @subtables = subtables
    @gid_cache = {}
  end

  attr_reader :gid_cache

  def convert_to_gid(str)
    str.unpack("U*").map {|cid| find_gid(cid) }
  end

  def find_gid(cid)
    if not @gid_cache.has_key?(cid)
      gid = CmapTable::GID_NOT_FOUND
      @subtables.each do |subtable|
        gid = subtable.find_gid(cid)
        break if gid != CmapTable::GID_NOT_FOUND
      end
      @gid_cache[cid] = gid
    end
    @gid_cache[cid]
  end

end

if __FILE__ == $0
  require_relative 'table_directory'

  if ARGV.empty?
    raise "No font file is specified."
  end

  filename = ARGV[0]

  File.open(filename, 'rb') do |file|
    table_directory = TableDirectory.from_file(file)
    cmap_table = CmapTable.from_file(file, table_directory.records['cmap'])

    ["ABCDE", "あいうえお", "斉斎齊齋", "\u{20B9F}\u{20D45}\u{20E6D}"].each do |str|
      puts "string: #{str}"
      puts "  unicode: #{str.unpack('U*')}"
      puts "  glyph  : #{cmap_table.convert_to_gid(str)}"
    end
  end
end
