require 'rails_helper'
require Rails.root.join('db/data/20261003130000_correct_limited_weapon_pools')

RSpec.describe CorrectLimitedWeaponPools do
  subject(:migration) { described_class.new }

  let!(:weapons) do
    described_class::WEAPONS.to_h do |change|
      attributes = { name_en: change[:name], recruits: change[:recruits], promotions: change[:before] }
      # The canonical seed already carries some of these weapons.
      weapon = Weapon.find_by(granblue_id: change[:granblue_id])&.tap { |row| row.update_columns(attributes) }
      [change[:granblue_id], weapon || create(:weapon, granblue_id: change[:granblue_id], **attributes)]
    end
  end
  let!(:yukata) { CharacterSeries.find_by(slug: 'yukata') || create(:character_series, slug: 'yukata') }
  let!(:arulumaya) do
    Character.find_by(granblue_id: '3030249000')&.tap { |row| row.update_columns(name_en: 'Arulumaya', rarity: 2) } ||
      create(:character, granblue_id: '3030249000', name_en: 'Arulumaya', rarity: 2)
  end

  it 'applies the reviewed pools, recruits and Yukata tagging, rerunnably' do
    2.times do
      migration.up
      expect(weapons['1040108200'].reload.promotions).to eq([5])
      expect(weapons['1040917100'].reload.promotions).to eq([5])
      expect(weapons['1040511900'].reload.promotions).to eq([5])
      expect(weapons['1040423400'].reload.promotions).to eq([7])
      expect(weapons['1040320300'].reload).to have_attributes(promotions: [7], recruits: '3040665000')
      expect(weapons['1040221400'].reload).to have_attributes(promotions: [7], recruits: '3040664000')
      expect(weapons['1030606800'].reload).to have_attributes(promotions: [7], recruits: '3030249000')
      expect(arulumaya.reload.season).to eq(3)
      expect(arulumaya.character_series_records).to contain_exactly(yukata)
      expect(arulumaya.read_attribute(:series)).to eq([11])
    end
  end

  it 'leaves other items untouched' do
    weapon = create(:weapon, promotions: [4])
    migration.up
    expect(weapon.reload.promotions).to eq([4])
  end

  it 'aborts before writing when a weapon is in unexpected pools' do
    weapons['1040511900'].update_column(:promotions, [4])
    expect { migration.up }.to raise_error(/Pool drift for 1040511900/)
    expect(weapons['1040108200'].reload.promotions).to eq([4])
  end

  it 'aborts before writing when a weapon recruits someone unexpected' do
    weapons['1030606800'].update_column(:recruits, '3049999999')
    expect { migration.up }.to raise_error(/Recruitment mismatch for 1030606800/)
    expect(weapons['1040108200'].reload.promotions).to eq([4])
  end

  it 'aborts before writing when the character has drifted' do
    arulumaya.update_column(:rarity, 3)
    expect { migration.up }.to raise_error(/Character mismatch for 3030249000/)
    expect(weapons['1040108200'].reload.promotions).to eq([4])
  end
end
