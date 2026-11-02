# frozen_string_literal: true

require 'rails_helper'
require Rails.root.join('db/data/20261102200000_prefix_event_kamigame_paths')

RSpec.describe PrefixEventKamigamePaths do
  subject(:migration) { described_class.new }

  before { allow(migration).to receive(:say) }

  it 'puts existing paths under イベント/, once, and leaves blanks alone' do
    old = create(:event, kamigame: '天上劇団もぐら座/index')
    done = create(:event, kamigame: 'イベント/決戦！星の古戦場/勲章')
    blank = create(:event, kamigame: nil)

    2.times { migration.up }

    expect(old.reload.kamigame).to eq('イベント/天上劇団もぐら座/index')
    expect(done.reload.kamigame).to eq('イベント/決戦！星の古戦場/勲章')
    expect(blank.reload.kamigame).to be_nil
  end

  it 'strips the folder on the way down' do
    event = create(:event, kamigame: 'イベント/天上劇団もぐら座/index')

    migration.down

    expect(event.reload.kamigame).to eq('天上劇団もぐら座/index')
  end
end
