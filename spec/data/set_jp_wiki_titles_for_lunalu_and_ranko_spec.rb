# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'SetJpWikiTitlesForLunaluAndRanko' do
  let(:migration_class) do
    require Rails.root.join('db/data/20261115140000_set_jp_wiki_titles_for_lunalu_and_ranko') unless defined?(SetJpWikiTitlesForLunaluAndRanko)
    SetJpWikiTitlesForLunaluAndRanko
  end

  def summon(granblue_id, wiki_ja)
    Summon.without_aura_build do
      record = Summon.find_by(granblue_id: granblue_id) || create(:summon, granblue_id: granblue_id)
      record.update_columns(wiki_ja: wiki_ja)
      record
    end
  end

  def run
    migration_class.new.tap { |m| m.verbose = false }.up
  end

  it 'sets the summon titles' do
    lunalu = summon('2040286000', 'ルナール (R)')
    ranko = summon('2040057000', '神崎蘭子 (SR)')

    run

    expect(lunalu.reload.wiki_ja).to eq('召喚石/ルナール (SSR)')
    expect(ranko.reload.wiki_ja).to eq('召喚石/［覚醒魔王］神崎蘭子 (SSR)')
  end

  it 'reports nothing to change on a second run' do
    summon('2040286000', 'ルナール (R)')
    run
    migration = migration_class.new.tap { |m| m.verbose = false }
    allow(migration).to receive(:say)
    migration.up
    expect(migration).to have_received(:say).with('set the Japanese wiki title on 0 summons')
  end
end
