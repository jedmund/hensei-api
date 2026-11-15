# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Granblue::Downloaders::JpSummonListDownloader do
  def row(id, name, aura)
    %(<tr><td><a href="./?plugin=attach&amp;openfile=#{id}.png">img</a></td><td>#{name}</td><td>#{aura}</td></tr>)
  end

  let(:pages) do
    {
      '召喚石R' => "<table>#{row('2020012000', 'ミノタウロス', '火属性攻撃力が10%(15%)UP')}</table>",
      '召喚石SR' => '<table><tr><th>名前</th></tr></table>',
      '召喚石SSR' => "<table>#{row('2040454000', 'ザマルヴォッチ (SSR)', 'メイン装備時：…')}" \
                  "#{row('2040098000', 'ゼピュロス (SSR)', 'メイン装備時：…')}</table>"
    }
  end
  let(:client) { instance_double(Granblue::Parsers::JpWiki) }
  let(:io) { StringIO.new }

  def summon(granblue_id, page: nil)
    Summon.without_aura_build { create(:summon, granblue_id: granblue_id, wiki_raw_jp: page) }
  end

  before do
    allow(client).to receive(:fetch) { |title| pages.fetch(title) }
    allow(Granblue::WikiThrottle).to receive(:wait)
  end

  it 'stores the list row for summons with no page of their own, matched by granblue_id' do
    minotaur = summon('2020012000')
    zamalvoch = summon('2040454000')

    summary = described_class.backfill(ids: [minotaur.granblue_id, zamalvoch.granblue_id], io: io, client: client)

    expect(minotaur.reload.wiki_raw_jp).to include('火属性攻撃力が10%(15%)UP').and start_with('<div class="gbf-wiki-list-row" data-page="召喚石R">')
    expect(zamalvoch.reload.wiki_raw_jp).to include('data-page="召喚石SSR"')
    expect(summary.changed).to eq(2)
    expect(client).to have_received(:fetch).exactly(3).times
  end

  it "never replaces a summon's own page" do
    zephyrus = summon('2040098000', page: '<div id="body">ゼピュロスの加護</div>')
    described_class.backfill(io: io, client: client)
    expect(zephyrus.reload.wiki_raw_jp).to eq('<div id="body">ゼピュロスの加護</div>')
  end

  it 'skips summons that are on no list page' do
    missing = summon('2040458000')
    summary = described_class.backfill(ids: [missing.granblue_id], io: io, client: client)
    expect(missing.reload.wiki_raw_jp).to be_blank
    expect(summary.skips).to eq('not on the list pages' => 1)
  end

  it 'is unchanged on a second run' do
    minotaur = summon('2020012000')
    described_class.backfill(ids: [minotaur.granblue_id], io: io, client: client)
    expect(described_class.backfill(ids: [minotaur.granblue_id], io: io, client: client))
      .to have_attributes(changed: 0, fetched: 1)
  end
end
