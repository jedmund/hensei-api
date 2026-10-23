# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SummonAuras::BuildJob do
  include ActiveJob::TestHelper

  let(:wiki) { "{{Summon\n|aura1=50% boost to Water Elemental ATK.\n}}" }
  let(:summon) { Summon.without_aura_build { create(:summon, granblue_id: '2040900001', element: 3, wiki_raw: wiki) } }

  around do |example|
    saved = ENV.fetch('SUMMON_AURA_BUILD', nil)
    ENV.delete('SUMMON_AURA_BUILD')
    example.run
  ensure
    saved.nil? ? ENV.delete('SUMMON_AURA_BUILD') : ENV['SUMMON_AURA_BUILD'] = saved
  end

  def values = SummonAura.where(summon_granblue_id: summon.granblue_id).pluck(:value)

  it 'builds a summon with no auras even in shadow mode' do
    ENV['SUMMON_AURA_BUILD'] = 'shadow'
    summary = described_class.perform_now(summon.id)
    expect(summary.mode).to eq('write')
    expect(values).to eq([50])
    expect(summon.reload.summon_aura_build_fingerprint).to be_present
  end

  it 'only reports for a summon with auras in shadow mode' do
    described_class.perform_now(summon.id)
    put_source(summon, :wiki_raw, wiki.sub('50%', '60%'))
    ENV['SUMMON_AURA_BUILD'] = 'shadow'

    summary = described_class.perform_now(summon.id)
    expect(summary.mode).to eq('shadow')
    expect(summary.differing).to eq(1)
    expect(values).to eq([50])
  end

  it 'writes a summon with auras in write mode' do
    described_class.perform_now(summon.id)
    put_source(summon, :wiki_raw, wiki.sub('50%', '60%'))
    ENV['SUMMON_AURA_BUILD'] = 'write'

    described_class.perform_now(summon.id)
    expect(values).to eq([60])
  end

  it 'is discarded when the summon is gone' do
    expect { described_class.perform_now(SecureRandom.uuid) }.not_to raise_error
  end

  describe 'Summon hooks' do
    it 'queues a build when a summon is created with a page' do
      expect { create(:summon, wiki_raw: wiki) }.to have_enqueued_job(described_class)
    end

    it 'queues a build when the page or the element changes' do
      summon
      expect { summon.update!(wiki_raw: wiki.sub('50%', '60%')) }.to have_enqueued_job(described_class).with(summon.id)
      expect { summon.update!(element: 2) }.to have_enqueued_job(described_class).with(summon.id)
    end

    it 'queues a build when the page is stored outside a save' do
      summon
      expect { Source.put(summon, :wiki_raw, wiki.sub('50%', '70%')) }.to have_enqueued_job(described_class).with(summon.id)
    end

    it 'queues nothing for other changes, a summon with nothing to build, or inside without_aura_build' do
      summon
      expect { summon.update!(name_en: 'Renamed') }.not_to have_enqueued_job(described_class)
      expect { create(:summon) }.not_to have_enqueued_job(described_class)
      expect { Summon.without_aura_build { summon.update!(element: 4) } }.not_to have_enqueued_job(described_class)
    end
  end
end
