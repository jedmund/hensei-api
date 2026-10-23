require 'rails_helper'
require Rails.root.join('db/data/20261003140000_correct_parsed_rarities_and_max_levels')

RSpec.describe CorrectParsedRaritiesAndMaxLevels do
  subject(:migration) { described_class.new }

  # The canonical seed already carries some of these items.
  def upsert(model, factory, granblue_id, attributes)
    model.find_by(granblue_id: granblue_id)&.tap { |row| row.update_columns(attributes) } ||
      create(factory, granblue_id: granblue_id, **attributes)
  end

  let!(:weapons) do
    described_class::WEAPONS.to_h do |granblue_id, name, rarity, level|
      [granblue_id, upsert(Weapon, :weapon, granblue_id, name_en: name, rarity: rarity, max_level: level)]
    end
  end
  let!(:belle) { upsert(Summon, :summon, '2030051000', name_en: 'Belle Sylphid', rarity: 2, max_level: 100) }
  let!(:zeta) { upsert(Character, :character, '3030231000', name_en: 'Zeta', rarity: 1) }

  it 'applies the reviewed rarities and max levels, rerunnably' do
    2.times do
      migration.up
      expect(weapons['1020102100'].reload).to have_attributes(rarity: 1, max_level: 50)
      expect(weapons['1030605500'].reload).to have_attributes(rarity: 2, max_level: 75)
      expect(weapons['1030704900'].reload).to have_attributes(rarity: 2, max_level: 75)
      expect(weapons['1030902400'].reload).to have_attributes(rarity: 2, max_level: 120)
      expect(weapons['1030902600'].reload).to have_attributes(rarity: 2, max_level: 120)
      expect(belle.reload.max_level).to eq(75)
      expect(zeta.reload.rarity).to eq(2)
    end
  end

  it 'leaves other items untouched' do
    weapon = create(:weapon, rarity: 3, max_level: 100)
    migration.up
    expect(weapon.reload).to have_attributes(rarity: 3, max_level: 100)
  end

  it 'aborts before writing when a value has drifted' do
    weapons['1030605500'].update_column(:max_level, 150)
    expect { migration.up }.to raise_error(/Value drift for 1030605500/)
    expect(weapons['1020102100'].reload.max_level).to eq(100)
  end

  it 'aborts before writing when an item has a different name' do
    zeta.update_column(:name_en, 'Not Zeta')
    expect { migration.up }.to raise_error(/Name mismatch for 3030231000/)
    expect(weapons['1020102100'].reload.max_level).to eq(100)
  end
end
