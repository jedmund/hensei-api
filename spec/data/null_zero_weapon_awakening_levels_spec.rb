# frozen_string_literal: true

require 'rails_helper'
require Rails.root.join('db/data/20261101120100_null_zero_weapon_awakening_levels')

RSpec.describe NullZeroWeaponAwakeningLevels do
  subject(:migration) { described_class.new }

  let(:stamp) { Time.zone.parse('2026-01-01 00:00') }

  let!(:zero) { stored({ max_awakening_level: 0 }) }
  let!(:awakened) { stored({ max_awakening_level: 15 }) }

  before { allow(migration).to receive(:say) }

  # Stored as the legacy rows are: update_columns skips validations and normalization.
  def stored(attributes, *traits)
    weapon = create(:weapon, *traits)
    weapon.update_columns(attributes.merge(updated_at: stamp))
    weapon
  end

  it 'sets zero awakening levels to NULL, rerunnably, and leaves real levels alone' do
    2.times do
      migration.up
      expect(zero.reload.max_awakening_level).to be_nil
    end
    expect(zero.updated_at).to be > stamp
    expect(awakened.reload).to have_attributes(max_awakening_level: 15, updated_at: stamp)
  end
end
