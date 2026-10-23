# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CharacterSkills::EffectCategory do
  def call(details: [], ids: ['1463'], **rest)
    described_class.call(game: { details: details, ids: ids }, vote: rest.delete(:vote), **rest)
  end

  it 'decides in order: special, game, curated, text rule, usual' do
    buff_in_game = [{ id: '1463', category: 'buff' }]
    expect(call(details: buff_in_game, special: true, vote: 'debuff').to_h).to eq(category: 'special', source: :special)
    expect(call(details: buff_in_game, curated: 'debuff', vote: 'debuff').to_h).to eq(category: 'buff', source: :game)
    expect(call(curated: 'debuff', vote: 'buff').to_h).to eq(category: 'debuff', source: :curated)
    expect(call(vote: 'buff', usual: 'debuff').to_h).to eq(category: 'buff', source: :rule)
    expect(call(vote: nil, usual: 'debuff').to_h).to eq(category: 'debuff', source: :usual)
  end

  it "ignores the game when its hits for the status disagree in this skill" do
    split = [{ id: '1463', category: 'buff' }, { id: '1463', category: 'debuff' }]
    expect(call(details: split, vote: 'debuff').source).to eq(:rule)
  end
end
