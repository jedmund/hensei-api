# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'CopyBeelzebubJpAuraToSupremeConqueror' do
  let(:migration_class) do
    unless defined?(CopyBeelzebubJpAuraToSupremeConqueror)
      require Rails.root.join('db/data/20261115130000_copy_beelzebub_jp_aura_to_supreme_conqueror')
    end
    CopyBeelzebubJpAuraToSupremeConqueror
  end

  let(:beelzebub_page) do
    '<div id="body"><table><tbody><tr><th>ベルゼバブ</th></tr>' \
      '<tr><th class="style_th" rowspan="3">加護</th><th>名称</th><th>効果</th></tr>' \
      '<tr><td rowspan="2">一にして全、全にして一</td><td><strong>メイン装備時：</strong>' \
      '全属性攻撃力が80<span style="color:#ff6600">(90)</span>%UP</td></tr>' \
      '<tr><td><strong>サブ装備時：</strong>主人公のトランスLvが1上昇(最大3)</td></tr>' \
      '<tr><th>フレーバーテキスト</th><td>望むは世界を統べる全一の王。</td></tr></tbody></table></div>'
  end

  # The test database seeds some summons (Beelzebub among them): reuse a seeded row.
  def summon(granblue_id, page)
    Summon.without_aura_build do
      record = Summon.find_by(granblue_id: granblue_id) || create(:summon, granblue_id: granblue_id)
      record.update!(wiki_raw_jp: page)
      record
    end
  end

  def run
    migration_class.new.tap { |m| m.verbose = false }.up
  end

  it "copies only Beelzebub's aura rows, under The Supreme Conqueror's aura name" do
    summon('2040408000', beelzebub_page)
    conqueror = summon('2040458000', nil)

    run

    page = conqueror.reload.wiki_raw_jp
    expect(page).to include('闘争の果て、力の頂', '全属性攻撃力が80', 'color:#ff6600', 'サブ装備時：')
    expect(page).not_to include('一にして全、全にして一', 'ベルゼバブ', 'フレーバーテキスト')
  end

  it 'leaves a page of its own alone, and is unchanged on a second run' do
    summon('2040408000', beelzebub_page)
    conqueror = summon('2040458000', nil)
    run
    copied = conqueror.reload.wiki_raw_jp
    run
    expect(conqueror.reload.wiki_raw_jp).to eq(copied)

    conqueror.update!(wiki_raw_jp: '<div id="body">闘争の果て、力の頂</div>')
    run
    expect(conqueror.reload.wiki_raw_jp).to eq('<div id="body">闘争の果て、力の頂</div>')
  end
end
