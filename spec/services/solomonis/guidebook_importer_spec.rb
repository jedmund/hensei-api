# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Solomonis::GuidebookImporter do
  def entry(overrides = {})
    {
      'name' => 'ATK +20%', 'target_type' => nil, 'target_param' => '', 'display_ailment_id' => nil,
      'status_id' => 1, 'icon_category' => 1, 'icon_type' => 1, 'rarity' => 1,
      'is_duplication_possible' => 1, 'deck_condition' => 0, 'num' => 1
    }.merge(overrides)
  end

  describe 'display values' do
    let!(:effect) do
      create(:solomonis_guide_effect, granblue_id: 96, stackable: false,
                                      name_en: 'Autorevive / Amplify DMG ({value} / Max: 100%) (Can\'t be stacked)')
    end

    it 'extracts the run value against the template, ignoring @@ breaks' do
      text = "Autorevive / Amplify DMG@@(30% / Max: 100%)@@(Can't be stacked)"
      result = described_class.new([entry('status_id' => 96, 'name' => text)]).call

      expect(result.first).to include(solomonis_guide_effect: effect, count: 1, display_value: '30%')
    end

    it 'leaves the value empty when the text no longer matches' do
      result = described_class.new([entry('status_id' => 96, 'name' => 'Something else')]).call

      expect(result.first[:display_value]).to be_nil
    end

    it 'saves a non-stackable effect once, with a warning' do
      importer = described_class.new([entry('status_id' => 96, 'num' => 2, 'name' => 'x')])

      expect(importer.call.first[:count]).to eq(1)
      expect(importer.warnings).to eq(["Guidebook effect 96 can't stack but the game shows 2; saved as 1"])
    end
  end

  it 'keeps the first of repeated entries' do
    create(:solomonis_guide_effect, granblue_id: 1, name_en: 'ATK +20%')
    importer = described_class.new([entry('num' => 2), entry('num' => 5)])

    expect(importer.call.map { |e| e[:count] }).to eq([2])
    expect(importer.warnings).to eq(['Guidebook effect 1 is listed 2 times; kept the first'])
  end

  it 'adds a race effect with its races' do
    described_class.new([entry('status_id' => 500, 'target_type' => 1, 'target_param' => '2_8', 'rarity' => 2)]).call

    expect(SolomonisGuideEffect.find_by(granblue_id: 500))
      .to have_attributes(rarity: 'rare', target_type: 'race', target_values: [2, 8], needs_review: true)
  end

  it 'skips a new effect with an unreadable target' do
    importer = described_class.new([entry('status_id' => 500, 'target_type' => 1, 'target_param' => '2;drop')])

    expect(importer.call).to eq([])
    expect(importer.warnings).to eq(['New guidebook effect 500 has an unreadable target; skipped'])
  end

  it 'skips names that are too long' do
    importer = described_class.new([entry('status_id' => 500, 'name' => 'x' * 1001)])

    expect(importer.call).to eq([])
    expect(importer.warnings).to eq(['Guidebook entry 1 (status 500) has no usable name; skipped'])
  end

  it 'carries hand-entered fields over from the previous guidebook' do
    effect = create(:solomonis_guide_effect, granblue_id: 1, name_en: 'ATK +20%')
    previous = build(:expedition_guide_effect, solomonis_guide_effect: effect, inherited: true, note: 'kept',
                                               acquired_order: 3)

    result = described_class.new([entry]).call(previous: { effect.id => previous })

    expect(result.first).to include(inherited: true, note: 'kept', acquired_order: 3)
  end

  it 'rejects more than 300 entries' do
    expect { described_class.new(Array.new(301) { entry }).call }.to raise_error(described_class::TooManyEntries)
  end
end
