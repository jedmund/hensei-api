# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BannerHistory::ArchiveParser do
  let(:wikitext) do
    <<~WIKI
      |- style="background-color:#FFE5BF; border-top:solid 3px;"
      | style="background-color:#FFE5BF !important;" data-sort-value="2022-12-31" | '''[https://granbluefantasy.jp/pages/?p=44737 Premium Gala]'''
      | 2022-12-31<br/>(12:00)<!--https://game.granbluefantasy.jp/#news/detail/9859/2/1/1-->
      | [[Makura]]<br/>[[Michael]]
      | [[Yatima (Summon)]]
      |- class="expand-child" style="text-align: left;"
      | colspan="5" | Sparkable Zodiacs: [[Makura]]
      |- class="expand-child" style="text-align: left;"
      | colspan="5" | {{tt|Rate Up SSR Char|0.300% per featured character|text-align=left}}: [[Makura]], [[Reinhardtzar (Grand)]], [[Cain_(Grand)|Cain]]
      |- class="expand-child" style="text-align: left;"
      | colspan="5" | {{tt|Rate Up Summons|0.250% per rate up summon|text-align=left}}: [[Yatima (Summon)]]
      |- style=" border-top:solid 3px;"
      | '''Character Rate Up:<br/>Holiday 2021'''
      | 2022-12-21<br/>(19:00)
      |- class="expand-child" style="text-align: left;"
      | colspan="5" | {{tt|Sparkable & Rate Up SSR Char|.233% per featured character|text-align=left}}: [[Altair (Holiday)]]
    WIKI
  end

  it 'reads gala and other rows with their times and labelled lists' do
    gala, seasonal = described_class.parse(wikitext)

    expect(gala).to include(type: 'premium', name: 'Premium Gala', start_date: Date.new(2022, 12, 31), start_time: '12:00')
    expect(gala[:lists]).to eq('zodiacs' => ['Makura'],
                               'rateup_char' => ['Makura', 'Reinhardtzar (Grand)', 'Cain (Grand)'],
                               'rateup_sum' => ['Yatima (Summon)'])
    expect(gala[:rates]['rateup_char']).to eq('0.300% per featured character')

    expect(seasonal).to include(type: 'archive', name: 'Character Rate Up: Holiday 2021', start_time: '19:00')
    expect(seasonal[:lists]).to eq('rateup_char' => ['Altair (Holiday)'])
  end

  it 'names galas by their titles' do
    expect(described_class.type('Flash Gala')).to eq('flash')
    expect(described_class.type('Legend Festival Pt 2')).to eq('legend')
    expect(described_class.type('Summons Rate Up: All')).to eq('archive')
  end
end
