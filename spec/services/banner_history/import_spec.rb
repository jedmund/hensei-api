# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BannerHistory::Import do
  let(:pages) do
    { 2026 => <<~WIKI }
      {{GachaBanner
      |type=premium
      |start_date=2026-10-31
      |zodiacs=Spec Zodiac
      |rateup_wep_ssr=Spec Arms
      |rateup_ssr_sum=Spec Poppet
      }}
      {{GachaBanner
      |type=poll
      |start_date=2026-11-04
      |sparkable_wep=Spec Vine;Spec Unknown
      }}
    WIKI
  end

  before do
    vikala = create(:character, granblue_id: '3049990002', name_en: 'Spec Zodiac', wiki_en: 'Spec Zodiac')
    create(:weapon, granblue_id: '1049990002', name_en: 'Spec Hairband', recruits: vikala.granblue_id)
    create(:weapon, granblue_id: '1049990003', name_en: 'Spec Arms', wiki_en: 'Spec Arms')
    create(:weapon, granblue_id: '1049990004', name_en: 'Spec Vine', wiki_en: 'Spec Vine')
    create(:summon, granblue_id: '2049990004', name_en: 'Spec Poppet', wiki_en: 'Spec Poppet')
  end

  def import = described_class.new(pages: pages, archive: nil).call

  it 'stores each banner with its pool, times and featured items' do
    result = import

    expect(result).to have_attributes(banners: 2, items: 4)
    expect(result.unresolved.keys).to eq([['Weapon', 'Spec Unknown']])

    gala = HistoricalBanner.find_by!(kind: 'premium')
    expect(gala).to have_attributes(pool: 'legend', ssr_rate: 6, source_key: 'Banner History/2026')
    expect(gala.ends_at).to eq(ActiveSupport::TimeZone['Asia/Tokyo'].parse('2026-11-04 18:59'))
    expect(gala.items.pluck(:granblue_id, :item_type, :role)).to contain_exactly(
      %w[1049990003 Weapon rate_up], %w[2049990004 Summon rate_up], %w[1049990002 Weapon zodiac]
    )
    expect(HistoricalBanner.find_by!(kind: 'poll').items.pluck(:granblue_id, :role)).to eq([%w[1049990004 featured]])
  end

  it 'replaces everything when run again' do
    import
    expect { import }.not_to change(HistoricalBanner, :count)
    expect(HistoricalBannerItem.count).to eq(4)
  end
end
