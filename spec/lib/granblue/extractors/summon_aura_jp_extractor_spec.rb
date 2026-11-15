# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Granblue::Extractors::SummonAuraJpExtractor do
  let(:extractor) { described_class.new }
  let(:main_cell) do
    '<strong>メイン装備時：</strong><br class="spacer">全属性攻撃力が80<span style="color:#ff6600">(90)</span>' \
      '<span style="color:#9932cc">(100)</span>%UP<span style="color:#9932cc">/<br class="spacer">主人公のステータス大幅UP</span>'
  end
  let(:sub_cell) { '<strong>サブ装備時：</strong><br class="spacer">主人公のトランスLvが1上昇(最大3)<br>◆連続攻撃確率UP' }

  def legend(*pairs)
    spans = pairs.map { |color, tier| %(<span style="color:#{color}">この色は#{tier}上限解放時</span>) }
    "<p>#{spans.join('、')}に追加される効果です。</p>"
  end

  def page(aura_cells, legend_html: legend(['#ff6600', '★3'], ['#9932cc', '★4']))
    <<~HTML
      <div id="body">#{legend_html}<table><tbody>
      <tr><th class="style_th" rowspan="3">加護</th><th>名称</th><th>効果</th></tr>
      <tr><td rowspan="2">ベルゼバブの加護</td><td>#{aura_cells.first}</td></tr>
      <tr><td>#{aura_cells.last}</td></tr>
      <tr><th>フレーバーテキスト</th><td>望むは世界を統べる全一の王。</td></tr>
      </tbody></table></div>
    HTML
  end

  def render(html, slot, uncap)
    extractor.text(extractor.extract(html), slot, uncap)
  end

  it 'renders each uncap tier from the colored variants, and adds text from its tier on' do
    html = page([main_cell, sub_cell])
    expect(render(html, 'main', 0)).to eq('全属性攻撃力が80%UP')
    expect(render(html, 'main', 3)).to eq('全属性攻撃力が90%UP')
    expect(render(html, 'main', 4)).to eq('全属性攻撃力が100%UP/主人公のステータス大幅UP')
  end

  it 'splits the main and sub auras, keeps the aura name, and breaks lines only before notes' do
    aura = extractor.extract(page([main_cell, sub_cell]))
    expect(aura.name).to eq('ベルゼバブの加護')
    expect(extractor.text(aura, 'sub', 0)).to eq("主人公のトランスLvが1上昇(最大3)\n◆連続攻撃確率UP")
  end

  it 'reads the tiers from the page legend' do
    html = page(['光属性攻撃力が100<span style="color:#9932cc">(120)</span>%UP', ''],
                legend_html: legend(['#9932cc', '★3']))
    expect(render(html, 'main', 3)).to eq('光属性攻撃力が120%UP')
  end

  it 'falls back to orange ★3, purple ★4, blue ★5 without a legend' do
    html = page(['攻撃力100<span style="color:purple">(110)</span><span style="color:blue">(130)</span>%UP', ''],
                legend_html: '')
    expect([0, 3, 4, 5].map { |u| render(html, 'main', u) }).to eq(%w[攻撃力100%UP 攻撃力100%UP 攻撃力110%UP 攻撃力130%UP])
  end

  it 'never renders text added after transcendence' do
    html = page([main_cell, '<strong>サブ装備時</strong><span style="color:#333399"><strong>風属性攻撃力が10%UP</strong></span>'],
                legend_html: "#{legend(['#ff6600', '★3'])}<span style=\"color:#333399\"><strong>この色は限界超越後</strong></span>")
    expect(render(html, 'sub', 5)).to be_nil
  end

  it 'reads a list-page row: the cell after the cooldown, without the element color' do
    row = '<div class="gbf-wiki-list-row" data-page="召喚石R"><table><tr><td>img</td><td>ミノタウロス</td>' \
          '<td><span style="color:#ff0000">火</span></td><td>敵全体に火属性ダメージ(中)</td><td>9ターン</td>' \
          '<td>火属性攻撃力が10%<span style="color:red">(15%)</span>UP</td><td>49</td></tr></table></div>'
    expect(render(row, 'main', 0)).to eq('火属性攻撃力が10%UP')
    expect(render(row, 'main', 3)).to eq('火属性攻撃力が15%UP')
    expect(render(row, 'sub', 0)).to be_nil
  end

  it 'returns nil without an aura' do
    expect(extractor.extract('<div id="body">プロフィール</div>')).to be_nil
    expect(render(nil, 'main', 0)).to be_nil
  end
end
