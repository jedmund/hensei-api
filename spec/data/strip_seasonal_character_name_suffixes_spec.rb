require 'rails_helper'
require Rails.root.join('db/data/20261003160000_strip_seasonal_character_name_suffixes')

RSpec.describe StripSeasonalCharacterNameSuffixes do
  subject(:migration) { described_class.new }

  let!(:characters) do
    described_class::CHARACTERS.to_h do |granblue_id, name_en, name_jp|
      attributes = { name_en: name_en, name_jp: name_jp }
      # The canonical seed already carries some of these characters.
      character = Character.find_by(granblue_id: granblue_id)&.tap { |row| row.update_columns(attributes) }
      [granblue_id, character || create(:character, granblue_id: granblue_id, **attributes)]
    end
  end

  it 'strips the season suffixes, rerunnably' do
    2.times do
      migration.up
      expect(characters['3040089000'].reload).to have_attributes(name_en: 'Narmaya', name_jp: 'ナルメア')
      expect(characters['3040055000'].reload).to have_attributes(name_en: 'Danua', name_jp: 'ダヌア')
      expect(characters['3030152000'].reload).to have_attributes(name_en: 'Camieux', name_jp: 'クムユ')
      expect(characters['3040135000'].reload).to have_attributes(name_en: 'Danua', name_jp: 'ダヌア')
      expect(characters['3020021000'].reload).to have_attributes(name_en: 'Anna', name_jp: 'アンナ')
    end
  end

  it 'keeps non-season suffixes' do
    migration.up
    expect(characters['3030246000'].reload).to have_attributes(name_en: 'Olivia (Event)', name_jp: 'オリヴィエ')
  end

  it 'aborts before writing when a name has drifted' do
    characters['3040266000'].update_column(:name_en, 'Not Teena')
    expect { migration.up }.to raise_error(/Missing Character 3040266000/)
    expect(characters['3040089000'].reload.name_en).to eq('Narmaya (Summer)')
  end
end
