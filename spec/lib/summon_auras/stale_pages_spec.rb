# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SummonAuras::StalePages do
  def summon(granblue_id, ulb: true, flb: true, transcendence: false, tiers: [0, 3, 4, 5], fetched: 1.week.ago,
             ulb_date: 1.month.ago.to_date)
    record = Summon.without_aura_build do
      create(:summon, granblue_id: granblue_id, wiki_en: "Spec #{granblue_id}", ulb: ulb, flb: flb,
                      transcendence: transcendence, ulb_date: ulb_date, wiki_raw: "{{Summon\n}}")
    end
    Source.where(owner_type: 'Summon', owner_id: record.id, kind: 'wiki_raw').update_all(fetched_at: fetched)
    tiers.each do |uncap|
      create(:summon_aura, summon_granblue_id: granblue_id, slot: 'main', uncap_level: uncap, target: 'other')
    end
    record
  end

  def stale = described_class.scope.where(granblue_id: %w[2040900101 2040900102 2040900103 2040900104 2040900105]).pluck(:granblue_id)

  it 'finds pages whose aura tiers stop short of the max uncap, or older than the latest uncap' do
    summon('2040900101')                                 # up to date
    summon('2040900102', tiers: [0, 3, 4])               # ULB, no 5★ tier: fetched before the wiki added it
    summon('2040900103', ulb_date: Date.current)         # uncapped after the fetch (latest_date)
    summon('2040900104', ulb: false, tiers: [0, 3, 4])   # FLB summon, complete
    summon('2040900105', transcendence: true)            # can transcend, no transcendence tiers

    expect(stale).to contain_exactly('2040900102', '2040900103', '2040900105')
  end

  it 'refetches the stale pages and stores them' do
    stale_summon = summon('2040900102', tiers: [0, 3, 4])
    fetcher = instance_double(Granblue::WikiFetcher)
    allow(Granblue::WikiFetcher).to receive(:new).and_return(fetcher)
    allow(fetcher).to receive(:fetch_and_store)
    allow(Granblue::WikiThrottle).to receive(:wait)
    allow(described_class).to receive(:scope).and_return(Summon.where(id: stale_summon.id))

    fetched, errors = described_class.refresh(io: StringIO.new)

    expect(fetcher).to have_received(:fetch_and_store).with(stale_summon)
    expect([fetched, errors]).to eq([['2040900102'], []])
  end
end
