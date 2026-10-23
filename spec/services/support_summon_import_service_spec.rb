require 'rails_helper'

RSpec.describe SupportSummonImportService do
  describe '.derive_uncap' do
    {
      1 => [0, 0],
      40 => [0, 0],
      41 => [1, 0],
      60 => [1, 0],
      61 => [2, 0],
      80 => [2, 0],
      81 => [3, 0],
      100 => [3, 0],
      101 => [4, 0],
      150 => [4, 0],
      151 => [5, 0],
      200 => [5, 0],
      201 => [6, 1],
      210 => [6, 1],
      211 => [6, 2],
      220 => [6, 2],
      221 => [6, 3],
      230 => [6, 3],
      231 => [6, 4],
      240 => [6, 4],
      241 => [6, 5],
      250 => [6, 5]
    }.each do |level, (uncap, transcendence)|
      it "returns [#{uncap}, #{transcendence}] for level #{level}" do
        expect(described_class.derive_uncap(level)).to eq([uncap, transcendence])
      end
    end
  end

  describe '#import' do
    let(:user) { create(:user) }
    let(:fire_summon) { create(:summon, element: 2) } # internal 2=Fire
    let(:water_summon) { create(:summon, element: 3) }
    let(:misc_summon) { create(:summon, element: 0) }

    it 'translates GBF section indices to internal section enums' do
      service = described_class.new(user, [
        { 'gbf_section' => 1, 'position' => 0, 'granblue_id' => fire_summon.granblue_id, 'level' => 250 },
        { 'gbf_section' => 2, 'position' => 0, 'granblue_id' => water_summon.granblue_id, 'level' => 200 },
        { 'gbf_section' => 0, 'position' => 0, 'granblue_id' => misc_summon.granblue_id, 'level' => 100 }
      ])

      result = service.import

      expect(result.success?).to be(true)
      sections = user.support_summons.ordered.map(&:section)
      expect(sections).to eq(%w[fire water misc])
    end

    it 'maps all 7 GBF section indices correctly' do
      summons = (0..6).map { create(:summon, element: 0) }
      items = (0..6).map do |gbf_section|
        { 'gbf_section' => gbf_section, 'position' => 0, 'granblue_id' => summons[gbf_section].granblue_id, 'level' => 100 }
      end

      result = described_class.new(user, items).import

      expect(result.success?).to be(true)
      expect(user.support_summons.pluck(:section).sort).to eq(%w[dark earth fire light misc water wind].sort)
    end

    it 'auto-creates a CollectionSummon when the user does not own the summon yet' do
      expect(user.collection_summons.count).to eq(0)

      result = described_class.new(user, [
        { 'gbf_section' => 1, 'position' => 0, 'granblue_id' => fire_summon.granblue_id, 'level' => 100 }
      ]).import

      expect(result.success?).to be(true)
      expect(user.collection_summons.count).to eq(1)
      cs = user.collection_summons.first
      expect(cs.summon).to eq(fire_summon)
      expect(cs.uncap_level).to eq(3) # level 100 → uncap 3
      expect(cs.transcendence_step).to eq(0)
    end

    it 'sets transcendence on an auto-created CollectionSummon when level is in the transcendence range' do
      transcendable = create(:summon, :transcendable)

      described_class.new(user, [
        { 'gbf_section' => 1, 'position' => 0, 'granblue_id' => transcendable.granblue_id, 'level' => 235 }
      ]).import

      cs = user.collection_summons.find_by(summon_id: transcendable.id)
      expect(cs.uncap_level).to eq(6)
      expect(cs.transcendence_step).to eq(4) # 231-240 → transcendence 4
    end

    it 'clamps transcendence_step to 0 for non-transcendable summons regardless of level' do
      # Level claims transcendence, but the summon doesn't support it.
      non_trans = create(:summon, transcendence: false)

      result = described_class.new(user, [
        { 'gbf_section' => 1, 'position' => 0, 'granblue_id' => non_trans.granblue_id, 'level' => 250 }
      ]).import

      expect(result.success?).to be(true)
      cs = user.collection_summons.find_by(summon_id: non_trans.id)
      expect(cs.transcendence_step).to eq(0)
    end

    it 'does not modify an existing CollectionSummon when one is already present' do
      existing = create(:collection_summon, user: user, summon: fire_summon, uncap_level: 5, transcendence_step: 0)

      described_class.new(user, [
        { 'gbf_section' => 1, 'position' => 0, 'granblue_id' => fire_summon.granblue_id, 'level' => 100 }
      ]).import

      existing.reload
      expect(existing.uncap_level).to eq(5)
      expect(existing.transcendence_step).to eq(0)
      # No duplicate CollectionSummon row was created either.
      expect(user.collection_summons.where(summon: fire_summon).count).to eq(1)
    end

    it 'atomically wipes existing support summons before inserting new ones' do
      existing_cs = create(:collection_summon, user: user, summon: water_summon)
      old_support = create(:support_summon, user: user, collection_summon: existing_cs, section: :water, position: 2)

      result = described_class.new(user, [
        { 'gbf_section' => 1, 'position' => 0, 'granblue_id' => fire_summon.granblue_id, 'level' => 100 }
      ]).import

      expect(result.success?).to be(true)
      expect(SupportSummon.find_by(id: old_support.id)).to be_nil
      expect(user.support_summons.map(&:section)).to eq(['fire'])
    end

    it 'rolls back the entire transaction when any row fails' do
      existing_cs = create(:collection_summon, user: user, summon: water_summon)
      old_support = create(:support_summon, user: user, collection_summon: existing_cs, section: :water, position: 0)

      result = described_class.new(user, [
        { 'gbf_section' => 1, 'position' => 0, 'granblue_id' => fire_summon.granblue_id, 'level' => 100 },
        { 'gbf_section' => 99, 'position' => 0, 'granblue_id' => water_summon.granblue_id, 'level' => 100 } # bad section
      ]).import

      expect(result.success?).to be(false)
      expect(result.errors.first[:error]).to include('Unknown GBF section')
      # Old slot still present; nothing from the failed import persisted.
      expect(SupportSummon.find_by(id: old_support.id)).to eq(old_support)
    end

    it 'reports an error when a granblue_id does not match any summon' do
      result = described_class.new(user, [
        { 'gbf_section' => 1, 'position' => 0, 'granblue_id' => 'not-a-real-id', 'level' => 100 }
      ]).import

      expect(result.success?).to be(false)
      expect(result.errors.first[:error]).to eq('Summon not found')
    end

    it 'accepts an empty payload as a clear-all operation' do
      existing_cs = create(:collection_summon, user: user, summon: fire_summon)
      create(:support_summon, user: user, collection_summon: existing_cs, section: :fire, position: 0)

      result = described_class.new(user, []).import

      expect(result.success?).to be(true)
      expect(user.support_summons).to be_empty
    end
  end
end
