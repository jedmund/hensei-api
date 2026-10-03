require 'rails_helper'
require Rails.root.join('db/data/20261003150000_normalize_premium_and_collab_pools')

RSpec.describe NormalizePremiumAndCollabPools do
  subject(:migration) { described_class.new }

  let(:ordinary) { [1, 4, 5, 6, 7, 8, 9, 10, 11] }

  # The canonical seed already carries some of these items.
  def upsert(model, factory, granblue_id, attributes)
    model.find_by(granblue_id: granblue_id)&.tap { |row| row.update_columns(attributes) } ||
      create(factory, granblue_id: granblue_id, **attributes)
  end

  let!(:reviewed) do
    described_class::CHANGES.to_h do |change|
      model, factory = change[:type] == 'Weapon' ? [Weapon, :weapon] : [Summon, :summon]
      [change[:granblue_id], upsert(model, factory, change[:granblue_id], name_en: change[:name], promotions: change[:before])]
    end
  end

  it 'brings every Premium item up to every non-Classic pool, keeping Classic pools' do
    premium_only = create(:weapon, promotions: [1])
    partial = create(:summon, promotions: [1, 4, 5, 6, 7, 8, 9])
    lower = create(:weapon, rarity: 2, promotions: [1, 2, 3, 12])
    shared = create(:summon, promotions: [1, 4, 5, 6, 7, 8, 9, 12])

    2.times do
      migration.up
      expect(premium_only.reload.promotions).to eq(ordinary)
      expect(partial.reload.promotions).to eq(ordinary)
      expect(lower.reload.promotions).to eq((ordinary + [2, 3, 12]).sort)
      expect(shared.reload.promotions).to eq(ordinary + [12])
    end
  end

  it 'leaves items outside Premium untouched' do
    limited = create(:weapon, promotions: [4])
    classic = create(:weapon, promotions: [3])
    migration.up
    expect(limited.reload.promotions).to eq([4])
    expect(classic.reload.promotions).to eq([3])
  end

  it 'applies the reviewed corrections' do
    migration.up
    expect(reviewed['2040460000'].reload.promotions).to eq([10])
    expect(reviewed['2040285000'].reload.promotions).to eq([12])
    expect(reviewed['1040802400'].reload.promotions).to eq([2])
    expect(reviewed['1040402900'].reload.promotions).to eq([])
  end

  it 'aborts before writing when a reviewed item is in unexpected pools' do
    premium_only = create(:weapon, promotions: [1])
    reviewed['2040326000'].update_column(:promotions, [3])
    expect { migration.up }.to raise_error(/Pool drift for 2040326000/)
    expect(premium_only.reload.promotions).to eq([1])
  end
end
