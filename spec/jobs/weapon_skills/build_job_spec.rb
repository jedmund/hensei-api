# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WeaponSkills::BuildJob do
  include ActiveJob::TestHelper
  include BuildLockHelpers

  let(:page) { Rails.root.join('spec/fixtures/wiki/hrunting.txt').read }
  let(:weapon) do
    Weapon.without_skill_build { create(:weapon, granblue_id: '1040022900', wiki_en: 'Hrunting', wiki_raw: page) }
  end
  let(:fetcher) { instance_double(WeaponSkills::SourceStore::Fetcher, fetch_weapon: nil, failures: []) }

  around do |example|
    saved = ENV.fetch('WEAPON_SKILL_BUILD', nil)
    ENV.delete('WEAPON_SKILL_BUILD')
    example.run
  ensure
    saved.nil? ? ENV.delete('WEAPON_SKILL_BUILD') : ENV['WEAPON_SKILL_BUILD'] = saved
  end

  before { allow(WeaponSkills::SourceStore::Fetcher).to receive(:new).and_return(fetcher) }

  it "fetches the pages the weapon's page follows, keeping the page, then builds a new weapon" do
    ENV['WEAPON_SKILL_BUILD'] = 'shadow'

    summary = described_class.perform_now(weapon.id)

    expect(fetcher).to have_received(:fetch_weapon).with(weapon, kinds: %w[expanded transclusion])
    expect(summary.built).to eq(1)
    expect(WeaponSkill.where(weapon_granblue_id: weapon.granblue_id)).to exist
    expect(weapon.reload.weapon_skill_build_fingerprint).to be_present
  end

  it 'only reports for a weapon with skills unless the build mode is write' do
    expect(described_class.mode_for(weapon)).to eq('write') # no skills yet
    described_class.perform_now(weapon.id)

    expect(described_class.mode_for(weapon)).to eq('shadow')
    ENV['WEAPON_SKILL_BUILD'] = 'shadow'
    expect(described_class.mode_for(weapon)).to eq('shadow')
    ENV['WEAPON_SKILL_BUILD'] = 'write'
    expect(described_class.mode_for(weapon)).to eq('write')
  end

  it 'builds from the stored pages when the fetch fails' do
    allow(fetcher).to receive(:fetch_weapon).and_raise(Granblue::WikiError, 'timeout')

    expect(described_class.perform_now(weapon.id).built).to eq(1)
  end

  it 're-queues itself while another weapon build runs' do
    weapon
    with_other_session do |session|
      session.exec_params('SELECT pg_advisory_lock($1, 0)', [WeaponSkills::BuildLock::BUILDS])

      expect { described_class.perform_now(weapon.id) }.to have_enqueued_job(described_class).with(weapon.id)
    end
    expect(WeaponSkill.where(weapon_granblue_id: weapon.granblue_id)).not_to exist
  end

  it 'is discarded when the weapon is gone' do
    expect { described_class.perform_now(SecureRandom.uuid) }.not_to raise_error
  end

  describe 'Weapon hooks' do
    it 'queues a build when a weapon is saved with a page and a page name' do
      expect { create(:weapon, wiki_en: 'New Blade', wiki_raw: page) }.to have_enqueued_job(described_class)
    end

    it 'queues a build when the page or its title changes' do
      weapon
      expect { weapon.update!(wiki_raw: "#{page}\n") }.to have_enqueued_job(described_class).with(weapon.id)
      expect { weapon.update!(wiki_en: 'Hrunting (Renamed)') }.to have_enqueued_job(described_class).with(weapon.id)
    end

    it 'queues nothing for other changes, a weapon with nothing to build, or inside without_skill_build' do
      weapon
      expect { weapon.update!(name_en: 'Renamed') }.not_to have_enqueued_job(described_class)
      expect { create(:weapon, wiki_raw: page) }.not_to have_enqueued_job(described_class) # no page name
      expect { Weapon.without_skill_build { weapon.update!(wiki_raw: "#{page}\n\n") } }
        .not_to have_enqueued_job(described_class)
    end
  end
end
