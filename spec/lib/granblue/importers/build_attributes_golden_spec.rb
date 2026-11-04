# frozen_string_literal: true

require 'rails_helper'

# Pins the attributes each catalogue importer builds from a CSV row: real rows
# from the test seed, plus rows that set every flag and leave every value blank.
#
# Regenerate with WRITE_GOLDENS=1 only for an intended change, and review the diff.
RSpec.describe 'Catalogue importer attributes' do
  let(:golden_dir) { Rails.root.join('spec/fixtures/importers') }

  def rows_for(csv_name)
    table = CSV.read(Rails.root.join("db/seed/test/#{csv_name}"), headers: true)
    # Columns the importers read that the test seed lacks
    headers = table.headers | %w[season series promotions max_transcendence_stage]
    filled = CSV::Row.new(headers, headers.map { |h| filled_value(h) })
    blank = CSV::Row.new(headers, headers.map { '' })
    [*table.first(3), filled, blank]
  end

  def filled_value(header)
    return 'true' if %w[flb ulb special transcendence subaura limit extra].include?(header)
    return '{1,2}' if %w[character_id series nicknames_en nicknames_jp promotions].include?(header)
    return '4.5' if header.start_with?('ougi_ratio')

    header.match?(/name|wiki|gamewith|kamigame|date|recruits|granblue_id/) ? "#{header}-value" : '3'
  end

  def expect_golden(name, actual)
    path = golden_dir.join("#{name}.json")
    if ENV['WRITE_GOLDENS']
      FileUtils.mkdir_p(golden_dir)
      File.write(path, "#{JSON.pretty_generate(actual)}\n")
    end
    expect(actual).to eq(JSON.parse(path.read))
  end

  {
    'character' => [Granblue::Importers::CharacterImporter, 'characters_test.csv'],
    'summon' => [Granblue::Importers::SummonImporter, 'summons_test.csv'],
    'weapon' => [Granblue::Importers::WeaponImporter, 'weapons_test.csv']
  }.each do |type, (klass, csv_name)|
    it "builds #{type} attributes from CSV rows" do
      importer = klass.new(Rails.root.join("db/seed/test/#{csv_name}").to_s)
      built = rows_for(csv_name).map { |row| importer.send(:build_attributes, row) }
      expect_golden("#{type}_attributes", JSON.parse(built.to_json))
    end
  end

  it 'zeroes max_transcendence_stage for a character without transcendence' do
    row = CSV::Row.new(%w[transcendence max_transcendence_stage], %w[false 5])
    attrs = Granblue::Importers::CharacterImporter.new('x.csv').send(:build_attributes, row)
    expect(attrs.values_at(:transcendence, :max_transcendence_stage, :ulb)).to eq([false, 0, false])
  end
end
