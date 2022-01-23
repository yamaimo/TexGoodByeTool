# TTCヘッダ

require_relative 'font_data_extension'
require_relative 'stack_pos_extension'
require_relative 'table_directory'
require_relative 'name_table'

class TtcHeader

  using FontDataExtension
  using StackPosExtension

  class Record

    def initialize(name, offset)
      @name = name
      @offset = offset
    end

    attr_reader :name, :offset

  end

  def self.from_file(file)
    ttc_tag = file.read_tag
    if ttc_tag != "ttcf"
      raise "Invalid ttc header."
    end

    # major_version(2byte), minor_version(2byte)はスキップ
    file.seek(4, IO::SEEK_CUR)

    num_fonts = file.read_uint32

    records = num_fonts.times.map do
      offset = file.read_uint32

      # コレクションを識別できる名前を探す
      name_ids = [
        NameTable::NameID::POSTSCRIPT_NAME,
        NameTable::NameID::FONT_SUBFAMILY_NAME,
        NameTable::NameID::TYPOGRAPHIC_SUBFAMILY_NAME,
      ]

      name = nil
      file.stack_pos do
        table_directory = TableDirectory.from_file(file, offset)
        name_table = NameTable.from_file(file, table_directory.records['name'])

        name_ids.each do |name_id|
          name = name_table.find(name_id)
          break if name
        end
        name = '(unknown)' if name.nil?
      end

      TtcHeader::Record.new(name, offset)
    end

    # DSIGは無視

    self.new(records)
  end

  def initialize(records)
    @records = records
  end

  attr_reader :records

end

if __FILE__ == $0
  if ARGV.empty?
    raise "No font collection file is specified."
  end

  filename = ARGV[0]

  ttc_header = nil
  File.open(filename, 'rb') do |file|
    ttc_header = TtcHeader.from_file(file)
  end

  ttc_header.records.each_with_index do |record, i|
    puts "[#{i}] #{record.name} (offset: #{record.offset})"
  end
end
