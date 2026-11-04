# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Granblue::CurationSnapshot::View, '.leveled_row?' do
  it "sees a skill's own rows that change with skill level" do
    expect(described_class.leveled_row?('sl10' => 30, 'sl15' => 32, 'sl20' => 35)).to be(true) # Concrio
    expect(described_class.leveled_row?('coefficient' => 50.4)).to be(true)
    expect(described_class.leveled_row?('condition' => { 'type' => 'copy_skill_level', 'gte' => 20 })).to be(true) # Malus Essence
  end

  it 'ignores fixed rows' do
    expect(described_class.leveled_row?('sl1' => 20, 'sl10' => 20, 'sl15' => 20)).to be(false)
    expect(described_class.leveled_row?('value' => 25, 'condition' => {})).to be(false)
  end
end
