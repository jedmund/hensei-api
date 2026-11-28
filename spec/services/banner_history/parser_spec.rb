# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BannerHistory::Parser do
  let(:wikitext) do
    <<~WIKI
      {| class="wikitable sortable"
      {{GachaBanner
      |type=flash#{' '}
      |start_date=2026-11-16
      |news_url=https://granbluefantasy.com/ja/news/9791/
      |rateup_wep_ssr=Sword of Resolve;Ignition Bandages
      |rateup_wep_grand=Pain and Suffering
      |prc_ft_ssr_char=.300
      }}

      {{GachaBanner
      |type=collab#{' '}
      |name=BLEACH
      |start_date=2026-07-22
      |start_time=17:00
      |end_date=2026-08-03
      |end_time=20:59
      |collab_wep=Hyorinmaru; Gamuza
      |collab_sum=Kisuke Urahara
      |rateup_ssr_sum=
      }}
    WIKI
  end

  it 'reads each banner with its type, dates and lists' do
    flash, collab = described_class.parse(wikitext, source_key: 'Banner History/2026')

    expect(flash).to include(type: 'flash', start_date: Date.new(2026, 11, 16), start_time: nil,
                             news_url: 'https://granbluefantasy.com/ja/news/9791/', source_key: 'Banner History/2026')
    expect(flash[:lists]).to eq('rateup_wep_ssr' => ['Sword of Resolve', 'Ignition Bandages'],
                                'rateup_wep_grand' => ['Pain and Suffering'])
    expect(flash[:rates]).to eq('prc_ft_ssr_char' => '.300')

    expect(collab).to include(type: 'collab', name: 'BLEACH', start_time: '17:00',
                              end_date: Date.new(2026, 8, 3), end_time: '20:59')
    expect(collab[:lists]).to eq('collab_wep' => %w[Hyorinmaru Gamuza], 'collab_sum' => ['Kisuke Urahara'])
  end

  it 'leaves a date it cannot read as nil' do
    expect(described_class.parse("{{GachaBanner\n|type=premium\n|start_date=soon\n}}").first[:start_date]).to be_nil
  end
end
