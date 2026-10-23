# frozen_string_literal: true

require 'rails_helper'
require Rails.root.join('db/data/20261023110000_decode_percent_encoded_jp_wiki_titles')

RSpec.describe DecodePercentEncodedJpWikiTitles do
  subject(:migration) { described_class.new }

  let(:truncated) { '%A5%B7%A5%E3%A5%EB%A5%ED%A5%C3%A5%C6%20%28SSR%29%A5%' }

  # Stored as the legacy rows are: update_columns skips the model's normalization.
  def stored(factory, wiki_ja)
    record = Character.without_skill_build { create(factory) }
    record.update_columns(wiki_ja: wiki_ja)
    record
  end

  let!(:utf8_character) { stored(:character, '%E3%83%86%E3%83%95%E3%83%8C%E3%83%88+%28SSR%29') }
  let!(:euc_weapon) { stored(:weapon, '%C9%F0%B4%EF%2F%A5%DE%A5%F3%A5%C7%A5%C8%20%28SSR%29') }
  let!(:mixed_summon) { stored(:summon, '召喚石/東堂+葵+%28SSR%29') }
  let!(:plain_summon) { stored(:summon, '召喚石/アグニス (SSR)') }
  let!(:broken_character) { stored(:character, truncated) }

  before { allow(migration).to receive(:say) }

  it 'rewrites percent-encoded titles as plain UTF-8, rerunnably' do
    2.times do
      migration.up
      expect(utf8_character.reload.wiki_ja).to eq('テフヌト (SSR)')
      expect(euc_weapon.reload.wiki_ja).to eq('武器/マンデト (SSR)')
      expect(mixed_summon.reload.wiki_ja).to eq('召喚石/東堂 葵 (SSR)')
      expect(plain_summon.reload.wiki_ja).to eq('召喚石/アグニス (SSR)')
    end
  end

  it 'leaves an undecodable title as it is and logs its id, not its value' do
    migration.up

    expect(broken_character.reload.wiki_ja).to eq(truncated)
    expect(migration).to have_received(:say).with(a_string_including(broken_character.granblue_id))
    expect(migration).not_to have_received(:say).with(a_string_including(truncated))
  end

  it 'starts no skill build' do
    allow(CharacterSkills::BuildJob).to receive(:perform_later)

    migration.up

    expect(CharacterSkills::BuildJob).not_to have_received(:perform_later)
  end
end
