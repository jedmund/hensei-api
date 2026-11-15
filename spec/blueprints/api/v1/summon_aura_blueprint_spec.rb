# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Api::V1::SummonAuraBlueprint do
  def render(aura) = JSON.parse(described_class.render(aura))

  it 'renders the English wikitext and the Japanese text as display segments' do
    aura = build(:summon_aura, description_en: "'''When main summon:'''<br />12 {{status|Wings of Promise|t=i}}.<ref name=\"x\" />",
                               description_jp: '全属性攻撃力が80%UP')

    segments = render(aura)['description_segments']

    expect(segments['en'].pluck('text').join).to eq("When main summon:\n12 Wings of Promise.")
    expect(segments['en'].first).to include('strong' => true)
    expect(segments['ja']).to eq([{ 'text' => '全属性攻撃力が80%UP' }])
  end

  it 'gives empty Japanese segments without Japanese text' do
    expect(render(build(:summon_aura, description_jp: nil))['description_segments']['ja']).to eq([])
  end
end
