# frozen_string_literal: true

require 'rails_helper'
require Rails.root.join('db/data/20261122100001_set_wonder_character_requirements')

RSpec.describe SetWonderCharacterRequirements do
  subject(:migration) { described_class.new }

  before { seed_wonder_catalogue! }

  it 'marks the character-specific Wonders, and runs again without change' do
    2.times { migration.up }

    expect(Wonder.find_by(granblue_id: '9003')).to have_attributes(required_character_series: 'eternal')
    expect(Wonder.find_by(granblue_id: '9016')).to have_attributes(required_character_series: 'zodiac')
    expect(Wonder.find_by(granblue_id: '29').required_character_game_ids).to eq([2005, 2006, 2007, 2008, 2010, 2124])
    expect(Wonder.where.not(granblue_id: %w[9003 9016 29]).select(&:character_specific?)).to be_empty
  end

  it 'clears them on the way down' do
    migration.up
    migration.down

    expect(Wonder.all.select(&:character_specific?)).to be_empty
  end
end
