require 'rails_helper'
require Rails.root.join('db/data/20261115160000_add_acies_summon_series')

RSpec.describe AddAciesSummonSeries do
  subject(:migration) { described_class.new }

  let!(:robur) { create(:summon_series, slug: 'robur', order: 14) }
  let!(:summer) { create(:summon_series, slug: 'summer', order: 15) }
  let!(:collab) { create(:summon_series, slug: 'collab', order: 19) }
  let!(:summons) do
    described_class::SUMMONS.map do |granblue_id, name_en|
      Summon.find_by(granblue_id: granblue_id)&.tap { |row| row.update_columns(name_en: name_en) } ||
        create(:summon, granblue_id: granblue_id, name_en: name_en)
    end
  end
  let!(:summer_bastet) { create(:summon, granblue_id: '2040437000', name_en: 'Bastet', summon_series: summer) }

  it 'adds Acies after Robur and moves its summons into it, rerunnably' do
    2.times do
      migration.up
      acies = SummonSeries.find_by!(slug: 'acies')
      expect(acies).to have_attributes(name_en: 'Acies Series', name_jp: 'アキエスシリーズ', order: 15)
      expect([robur, summer, collab].map { |s| s.reload.order }).to eq([14, 16, 20])
      expect(summons.map { |s| s.reload.summon_series_id }).to all(eq(acies.id))
    end
  end

  it 'leaves the summer Bastet in its series' do
    migration.up
    expect(summer_bastet.reload.summon_series_id).to eq(summer.id)
  end

  it 'aborts before writing when a summon is missing' do
    summons.first.update_column(:name_en, 'Not Lodern')
    expect { migration.up }.to raise_error(/Missing Summon 2040457000/)
    expect(SummonSeries.exists?(slug: 'acies')).to be(false)
  end
end
