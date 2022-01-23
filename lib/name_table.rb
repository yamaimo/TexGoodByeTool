# nameテーブル

require_relative 'font_data_extension'
require_relative 'stack_pos_extension'

class NameTable

  using FontDataExtension
  using StackPosExtension

  module NameID

    COPYRIGHT = 0
    FONT_FAMILY_NAME = 1
    FONT_SUBFAMILY_NAME = 2
    UNIQUE_FONT_IDENTIFIER = 3
    FULL_FONT_NAME = 4
    VERSION = 5
    POSTSCRIPT_NAME = 6

    TRADEMARK = 7
    MANUFACTURER = 8
    DESIGNER = 9
    DESCRIPTION = 10
    VENDOR_URL = 11
    DESIGNER_URL = 12
    LICENSE_DESCRIPTION = 13
    LICENSE_URL = 14

    TYPOGRAPHIC_FAMILY_NAME = 16
    TYPOGRAPHIC_SUBFAMILY_NAME = 17
    COMPATIBLE_FULL_NAME = 18
    SAMPLE_TEXT = 19
    POSTSCRIPT_CID_FINDFONT_NAME = 20
    WWS_FAMILY_NAME = 21
    WWS_SUBFAMILY_NAME = 22
    LIGHT_BACKGROUND_PALETTE = 23
    DARK_BACKGROUND_PALETTE = 24
    VARIATIONS_POSTSCRIPT_NAME_PREFIX = 25

  end

  class Record

    def initialize(str, platform_id, language_id)
      @str = str
      @platform_id = platform_id
      @language_id = language_id
    end

    attr_reader :str, :platform_id, :language_id

  end

  def self.from_file(file, name_record)
    file.seek(name_record.offset)

    # version(2byte)はスキップ
    file.seek(2, IO::SEEK_CUR)

    count = file.read_uint16
    storage_offset = file.read_offset16

    # ファイル先頭からのオフセットにしておく
    storage_offset += name_record.offset

    records_for_id = {}
    count.times.map do |i|
      platform_id = file.read_uint16
      encoding_id = file.read_uint16
      language_id = file.read_uint16

      encoding = case [platform_id, encoding_id]
                 when [0, 3], [0, 4], [3, 1], [3, 10] # Unicode
                  'UTF-16BE'
                 else
                   nil
                 end

      name_id = file.read_uint16
      length = file.read_uint16
      string_offset = file.read_offset16

      if encoding
        str = file.stack_pos do
          file.seek(storage_offset + string_offset)
          file.read_string(length, encoding)
        end
        record = Record.new(str, platform_id, language_id)

        records_for_id[name_id] ||= []
        records_for_id[name_id].push record
      end
    end

    # version1のlanguage tagは未対応

    self.new(records_for_id)
  end

  def initialize(records_for_id)
    @records_for_id = records_for_id
  end

  attr_reader :records_for_id

  def find(name_id, platform_id: 3, language_id: 0x409)
    name = nil

    if @records_for_id.has_key?(name_id)
      found = @records_for_id[name_id].find do |record|
        (record.platform_id == platform_id) && (record.language_id == language_id)
      end
      name = found.str if found
    end

    name
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
    name_table = NameTable.from_file(file, table_directory.records['name'])

    name_table.records_for_id.each do |name_id, records|
      puts "[#{name_id}]"
      records.each do |record|
        puts "  #{record.str} (platform: #{record.platform_id}, language: #{record.language_id})"
      end
    end
  end
end
