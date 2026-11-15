# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SummonAuras::Build do
  let(:wiki) do
    "{{Summon\n|aura1=80% boost to all Elemental ATK.\n|aura2=90% boost to all Elemental ATK.\n" \
      "|aura3=100% boost to all Elemental ATK.\n|aurat1=110% boost to all Elemental ATK.\n}}"
  end
  let(:jp_page) do
    '<div id="body"><p><span style="color:#ff6600">この色は★3上限解放時</span></p><table><tbody>' \
      '<tr><th>加護</th><th>名称</th><th>効果</th></tr><tr><td>名</td><td>メイン装備時：全属性攻撃力が80' \
      '<span style="color:#ff6600">(90)</span>%UP</td></tr><tr><th>フレーバーテキスト</th></tr></tbody></table></div>'
  end
  let(:summon) do
    Summon.without_aura_build { create(:summon, granblue_id: '2040900009', wiki_raw: wiki, wiki_raw_jp: jp_page) }
  end

  def jp_by_tier = described_class.for(summon).to_h { |r| [[r['uncap_level'], r['transcendence_stage']], r['description_jp']] }

  it 'writes the Japanese text for each tier the page states' do
    expect(jp_by_tier).to include([0, 0] => '全属性攻撃力が80%UP', [3, 0] => '全属性攻撃力が90%UP')
  end

  it "leaves it empty when the page doesn't state the tier's value, and for transcendence stages" do
    expect(jp_by_tier).to include([4, 0] => nil, [5, 1] => nil)
  end

  it 'leaves it empty without a Japanese page' do
    summon.update!(wiki_raw_jp: nil)
    expect(described_class.for(summon.reload).pluck('description_jp').uniq).to eq([nil])
  end

  describe "Japanese text for a capped aura (Grand Order's page)" do
    let(:wiki) do
      "{{Summon\n|aura1=Boost to Normal ATK (Max: 100%) for each weapon group.\n" \
        "|aura2=Boost to Normal ATK (Max: 100%) for each weapon group.\n" \
        "|aura3=40% boost to Normal ATK (Max: 200%) and 10% boost to DEF (Max: 50%) for each weapon group.\n" \
        "|aura4=40% boost to Normal ATK (Max: 200%) and 10% boost to DEF (Max: 50%) for each weapon group.\n}}"
    end
    # The page colors (200) as a ★3 addition, though 3★ caps at 100%
    let(:jp_page) do
      '<div id="body"><p><span style="color:#ff6600">この色は★3上限解放後</span>、' \
        '<span style="color:#9932cc">この色は★4上限解放後</span>、<span style="color:#1e90ff">この色は★5上限解放後</span></p>' \
        '<table><tbody><tr><th>加護</th><th>名称</th><th>効果</th></tr><tr><td>名</td><td>メイン装備時：' \
        '攻撃力UP(最大100<span style="color:#ff6600">(200)</span>%)<span style="color:#9932cc">/防御力UP(最大50%)</span>' \
        '<span style="color:#1e90ff">◆5種以上のとき奥義ゲージ10%UP</span></td></tr><tr><th>フレーバーテキスト</th></tr>' \
        '</tbody></table></div>'
    end

    it 'keeps the text that states the cap, and drops the 3★ text whose cap disagrees' do
      expect(jp_by_tier).to eq([0, 0] => '攻撃力UP(最大100%)', [3, 0] => nil,
                               [4, 0] => '攻撃力UP(最大200%)/防御力UP(最大50%)',
                               [5, 0] => '攻撃力UP(最大200%)/防御力UP(最大50%)◆5種以上のとき奥義ゲージ10%UP')
    end
  end

  describe '.names' do
    it 'takes the English name from aura_name and the Japanese one from the 加護 name cell' do
      summon.update!(wiki_raw: "#{wiki}\n|aura_name=Spec's Aura\n|jpaura_name=英語ページの加護\n")
      page = jp_page.sub('<td>名</td>', '<td>スペックの加護</td>')
      summon.update!(wiki_raw_jp: page)
      expect(described_class.names(summon.reload)).to eq('aura_name_en' => "Spec's Aura", 'aura_name_jp' => 'スペックの加護')
    end

    it "falls back to the English page's jpaura_name without a Japanese page" do
      summon.update!(wiki_raw: "#{wiki}\n|aura_name=Spec's Aura\n|jpaura_name=英語ページの加護\n", wiki_raw_jp: nil)
      expect(described_class.names(summon.reload)).to eq('aura_name_en' => "Spec's Aura", 'aura_name_jp' => '英語ページの加護')
    end

    it 'is nil where the pages have no name' do
      summon.update!(wiki_raw_jp: nil)
      expect(described_class.names(summon.reload)).to eq('aura_name_en' => nil, 'aura_name_jp' => nil)
    end
  end
end
