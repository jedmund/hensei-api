# frozen_string_literal: true

require 'rails_helper'
require Rails.root.join('db/data/20261101120200_raise_transcended_dark_opus_caps')

RSpec.describe RaiseTranscendedDarkOpusCaps do
  subject(:migration) { described_class.new }

  let(:stamp) { Time.zone.parse('2026-01-01 00:00') }

  # Stored as the legacy rows are: update_columns skips validations and normalization.
  def stored(attributes, *traits)
    weapon = create(:weapon, *traits)
    weapon.update_columns(attributes.merge(updated_at: stamp))
    weapon
  end

  before { allow(migration).to receive(:say) }

  let(:transcended) { { ulb: true, transcendence: true, max_level: 200, max_skill_level: 20 } }
  let!(:opus) { stored(transcended, :opus) }
  let!(:untranscended_opus) { stored(transcended.merge(transcendence: false), :opus) }
  let!(:edited_opus) { stored(transcended.merge(max_level: 210), :opus) }
  let!(:other_series) { stored(transcended) }

  it 'raises transcended Dark Opus weapons at 200/20 to 250/25, rerunnably' do
    2.times do
      migration.up
      expect(opus.reload).to have_attributes(max_level: 250, max_skill_level: 25)
    end
    expect(opus.updated_at).to be > stamp
  end

  it 'leaves other weapons alone' do
    migration.up
    expect(untranscended_opus.reload).to have_attributes(max_level: 200, max_skill_level: 20, updated_at: stamp)
    expect(edited_opus.reload).to have_attributes(max_level: 210, max_skill_level: 20, updated_at: stamp)
    expect(other_series.reload).to have_attributes(max_level: 200, max_skill_level: 20, updated_at: stamp)
  end
end
