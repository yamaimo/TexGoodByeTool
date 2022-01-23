# テーブルディレクトリ

require_relative 'font_data_extension'
require_relative 'sfnt_font_type'

class TableDirectory

  using FontDataExtension

  class Record

    def initialize(tag, checksum, offset, length)
      @tag = tag
      @checksum = checksum
      @offset = offset
      @length = length
    end

    attr_reader :tag, :checksum, :offset, :length

  end

  def self.from_file(file, offset = 0)
    file.seek(offset)

    version = file.read_tag
    type = if version == "OTTO"
             SfntFontType::OPEN_TYPE
           elsif version.unpack('N').first == 0x00010000
             SfntFontType::TRUE_TYPE
           else
             raise "Unknown type."
           end

    num_tables = file.read_uint16

    # search_range(2byte), entry_selector(2byte),
    # range_shift(2byte)はスキップ
    file.seek(6, IO::SEEK_CUR)

    records = {}
    num_tables.times do
      tag = file.read_tag
      checksum = file.read_uint32
      offset = file.read_uint32
      length = file.read_uint32
      records[tag] = Record.new(tag, checksum, offset, length)
    end

    self.new(type, records)
  end

  def initialize(type, records)
    @type = type
    @records = records
  end

  attr_reader :type, :records

end

if __FILE__ == $0
  if ARGV.empty?
    raise "No font file is specified."
  end

  filename = ARGV[0]

  table_directory = nil
  File.open(filename, 'rb') do |file|
    table_directory = TableDirectory.from_file(file)
  end

  puts "type  : #{table_directory.type}"
  puts "tables: #{table_directory.records.size}"
  table_directory.records.each.with_index do |(tag, record), i|
    puts "[#{i}] #{tag} " \
         "(checksum: #{record.checksum}, " \
         "offset: #{record.offset}, " \
         "length: #{record.length})"
  end
end
