# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'FixMinotaurAndRodflyElements' do
  include ActiveJob::TestHelper

  let(:migration_class) do
    require Rails.root.join('db/data/20261114120000_fix_minotaur_and_rodfly_elements') unless defined?(FixMinotaurAndRodflyElements)
    FixMinotaurAndRodflyElements
  end

  let(:rivacuda_page) do
    "{{Summon\n|id=2020023000\n|element=water\n|aura1=10% boost to Water Elemental ATK.\n" \
      "|aura2=15% boost to Water Elemental ATK.\n}}"
  end

  let!(:minotaur) do
    Summon.without_aura_build do
      create(:summon, granblue_id: '2020012000', element: 4,
                      wiki_raw: "{{Summon\n|aura1=10% boost to Fire Elemental ATK.\n}}")
    end
  end
  let!(:rodfly) { Summon.without_aura_build { create(:summon, granblue_id: '2020026000', element: 4, wiki_raw: rivacuda_page) } }

  def run
    migration_class.new.tap { |m| m.verbose = false }.up
  end

  it 'sets Minotaur to Fire and stores Rodfly its own page, without queuing builds' do
    expect { run }.not_to have_enqueued_job(SummonAuras::BuildJob)

    expect(minotaur.reload.element).to eq(1)
    expect(rodfly.reload.element).to eq(4)
    expect(rodfly.wiki_raw).to include("|id=2020026000\n", '|aura1=10% boost to Wind')
  end

  it 'makes the build write Wind auras for Rodfly' do
    run
    SummonAuras::Build::Runner.new(mode: 'write', io: StringIO.new, ids: [rodfly.granblue_id]).call

    expect(SummonAura.where(summon_granblue_id: rodfly.granblue_id).pluck(:uncap_level, :element, :value).sort)
      .to eq([[0, 'wind', 10.0], [3, 'wind', 15.0]])
  end

  it 'leaves both summons alone on a second run' do
    run
    page = rodfly.reload.wiki_raw
    run
    expect(minotaur.reload.element).to eq(1)
    expect(rodfly.reload.wiki_raw).to eq(page)
  end
end
