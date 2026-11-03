# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Api::V1::WeaponBlueprint do
  it 'includes a trimmed series in the list view so reps can pick transcendence art' do
    weapon = create(:weapon, :opus)

    series = described_class.render_as_hash(weapon, view: :list)[:series]

    expect(series).to eq(id: weapon.weapon_series_id, slug: 'dark-opus')
  end

  describe 'skills_built_at in the full view' do
    it 'is nil when the skill build has never run for the weapon' do
      weapon = create(:weapon, weapon_skill_built_at: nil)

      expect(described_class.render_as_hash(weapon, view: :full)[:skills_built_at]).to be_nil
    end

    it 'is when the skill build last ran' do
      built_at = Time.zone.parse('2026-10-20 12:00')
      weapon = create(:weapon, weapon_skill_built_at: built_at)

      expect(described_class.render_as_hash(weapon, view: :full)[:skills_built_at]).to eq(built_at)
    end
  end
end
