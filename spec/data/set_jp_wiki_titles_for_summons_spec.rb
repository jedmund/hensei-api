# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'SetJpWikiTitlesForSummons' do
  let(:migration_class) do
    require Rails.root.join('db/data/20261115120000_set_jp_wiki_titles_for_summons') unless defined?(SetJpWikiTitlesForSummons)
    SetJpWikiTitlesForSummons
  end

  def run
    migration_class.new.tap { |m| m.verbose = false }.up
  end

  it 'sets the listed titles and leaves other summons alone' do
    belial = Summon.without_aura_build { create(:summon, granblue_id: '2040411000') }
    belial.update_columns(wiki_ja: 'ベリアル(水着バージョン) (SSR)')
    medusa = Summon.without_aura_build { create(:summon, granblue_id: '2040059000') }
    medusa.update_columns(wiki_ja: nil)
    other = Summon.without_aura_build { create(:summon, granblue_id: '2040098000') }
    other.update_columns(wiki_ja: '召喚石/ゼピュロス (SSR)')

    run

    expect(belial.reload.wiki_ja).to eq('召喚石/ベリアル (SSR)水着バージョン')
    expect(medusa.reload.wiki_ja).to eq('召喚石/メドゥーサ (SSR)')
    expect(other.reload.wiki_ja).to eq('召喚石/ゼピュロス (SSR)')
  end

  it 'reports nothing to change on a second run' do
    Summon.without_aura_build { create(:summon, granblue_id: '2040059000') }.update_columns(wiki_ja: nil)
    run
    migration = migration_class.new.tap { |m| m.verbose = false }
    allow(migration).to receive(:say)
    migration.up
    expect(migration).to have_received(:say).with('set the Japanese wiki title on 0 summons')
  end
end
