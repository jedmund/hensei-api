require 'rails_helper'
require Rails.root.join('db/data/20261003120001_strip_grand_character_name_suffixes')

RSpec.describe StripGrandCharacterNameSuffixes do
  subject(:migration) { described_class.new }

  let!(:characters) do
    described_class::CHARACTERS.to_h do |granblue_id, name_en, name_jp|
      attributes = { name_en: name_en, name_jp: name_jp }
      # The canonical seed already carries some of these characters.
      character = Character.find_by(granblue_id: granblue_id)&.tap { |row| row.update_columns(attributes) }
      [granblue_id, character || create(:character, granblue_id: granblue_id, **attributes)]
    end
  end
  let!(:other_lecia) { create(:character, granblue_id: '3040101000', name_en: 'Lecia', name_jp: 'リーシャ') }

  it 'strips the suffixes, rerunnably' do
    2.times do
      migration.up
      expect(characters['3040092000'].reload).to have_attributes(name_en: 'Zooey', name_jp: 'ゾーイ')
      expect(characters['3040245000'].reload).to have_attributes(name_en: "Jeanne d'Arc", name_jp: 'ジャンヌダルク')
      expect(characters['3040082000'].reload).to have_attributes(name_en: 'Black Knight', name_jp: '黒騎士')
      expect(characters['3040357000'].reload).to have_attributes(name_en: 'Lich', name_jp: 'リッチ')
      expect(characters['3040101000'].reload).to have_attributes(name_en: 'Lecia', name_jp: 'リーシャ')
    end
  end

  it 'leaves the other character sharing an id untouched' do
    migration.up
    expect(other_lecia.reload).to have_attributes(name_en: 'Lecia', name_jp: 'リーシャ')
  end

  it 'aborts before writing when a name has drifted' do
    characters['3040467000'].update_column(:name_en, 'Not Cosmos')
    expect { migration.up }.to raise_error(/Missing Character 3040467000/)
    expect(characters['3040092000'].reload.name_en).to eq('Zooey (Grand)')
  end
end
