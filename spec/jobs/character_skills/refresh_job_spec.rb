# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CharacterSkills::RefreshJob do
  let(:editor) { create(:user, role: 7) }

  def wiki(cooldown)
    <<~WIKI
      {{Character
      |abilitycount=1
      |a1_name=Fire
      |a1_effdesc=Inflict {{status|Burned|a=5}}.
      |a1_cd={{InfoCd|num=1|cooldown=#{cooldown}}}
      |a1_icon=Ability_m_100_1.png
      }}
    WIKI
  end

  def make(granblue_id, **attrs)
    Character.without_skill_build do
      create(:character, granblue_id: granblue_id, element: 1, wiki_en: "Page #{granblue_id}", wiki_raw: wiki(7), **attrs)
    end
  end

  let!(:first) { make('3040900001') }
  let!(:second) { make('3040900002') }
  let(:batch) { CharacterSkills::RefreshBatch.create(user: editor, characters: [first, second], refetch_jp: false) }

  def reload_batch = CharacterSkills::RefreshBatch.find(batch.id)

  before do
    CharacterSkills::RefreshStore.clear
    allow(CharacterSkills::WikiPacer.instance).to receive(:wait)
    # The network is the wiki client; the fetcher and the pacer run for real.
    allow_any_instance_of(Granblue::Parsers::Wiki).to receive(:fetch) { |_, page| page == 'Page 3040900002' ? wiki(4) : wiki(5) }
  end

  describe 'preview' do
    it 'previews each character in order, paced, and writes nothing' do
      described_class.perform_now(batch.id, 'preview')

      state = reload_batch
      expect(state.status).to eq('previewed')
      expect(state.items.pluck(:status)).to eq(%w[previewed previewed])
      expect(state.items.map { |item| item[:refresh][:wiki_changed] }).to eq([true, true])
      expect(state.sources(first.id).wiki_raw).to eq(wiki(5))
      expect(state.sources(second.id).wiki_raw).to eq(wiki(4))
      expect(CharacterSkills::WikiPacer.instance).to have_received(:wait).with(:gbf_wiki).twice
      expect(first.reload.wiki_raw).to eq(wiki(7))
      expect(CharacterSkill.where(character_id: [first.id, second.id])).to be_empty
    end

    it 'marks a character whose page fails and carries on' do
      error = Granblue::WikiError.new(code: 502, message: 'Server error', page: 'Page 3040900001')
      allow_any_instance_of(Granblue::Parsers::Wiki).to receive(:fetch).with('Page 3040900001').and_raise(error)

      described_class.perform_now(batch.id, 'preview')

      state = reload_batch
      expect(state.status).to eq('previewed')
      expect(state.item(first.id)).to include(status: 'failed', refresh: nil,
                                              error: 'The wiki page Page 3040900001 could not be fetched (502)',
                                              error_code: 'wiki_fetch_failed', error_status: 502)
      expect(state.item(second.id)).to include(status: 'previewed', error: nil, error_code: nil, error_status: nil)
    end

    it 'codes an unreachable wiki as wiki_fetch_failed without a status' do
      allow_any_instance_of(Granblue::Parsers::Wiki).to receive(:fetch).with('Page 3040900001')
                                                                       .and_raise(Net::OpenTimeout, 'execution expired')

      described_class.perform_now(batch.id, 'preview')

      expect(reload_batch.item(first.id)).to include(status: 'failed', error_code: 'wiki_fetch_failed', error_status: nil,
                                                     error: include('could not be reached'))
    end

    it 'codes a build that makes no skills as build_refused' do
      allow_any_instance_of(Granblue::Parsers::Wiki).to receive(:fetch).with('Page 3040900001').and_return('{{Nothing}}')
      CharacterSkills::Build::Runner.new(mode: 'write', characters: [first], all: true, io: StringIO.new,
                                         enqueue_icons: false).call

      described_class.perform_now(batch.id, 'preview')

      expect(reload_batch.item(first.id)).to include(status: 'failed', error_code: 'build_refused', error_status: nil,
                                                     error: include('made no skills'))
    end

    it 'codes a missing Japanese page as build_refused' do
      first.update_columns(wiki_ja: nil, name_jp: nil)
      jp_batch = CharacterSkills::RefreshBatch.create(user: editor, characters: [first], refetch_jp: true)

      described_class.perform_now(jp_batch.id, 'preview')

      expect(CharacterSkills::RefreshBatch.find(jp_batch.id).item(first.id))
        .to include(status: 'failed', error_code: 'build_refused', error: include('Japanese wiki page'))
    end

    it 'codes anything else as unexpected' do
      allow_any_instance_of(CharacterSkills::Refresh).to receive(:preview).and_raise(NoMethodError, 'oops')

      described_class.perform_now(batch.id, 'preview')

      expect(reload_batch.item(first.id)).to include(status: 'failed', error_code: 'unexpected', error_status: nil,
                                                     error: 'NoMethodError: oops')
    end

    it 'fails the refresh when no character could be previewed' do
      allow_any_instance_of(Granblue::Parsers::Wiki).to receive(:fetch)
        .and_raise(Granblue::WikiError.new(code: 502, message: 'Server error', page: 'x'))

      described_class.perform_now(batch.id, 'preview')
      expect(reload_batch.status).to eq('failed')
    end

    it 'fails the refresh, without raising, when the run itself breaks' do
      allow_any_instance_of(CharacterSkills::RefreshBatch).to receive(:previewed_ids).and_raise('boom')

      expect { described_class.perform_now(batch.id, 'preview') }.not_to raise_error
      expect(reload_batch.status).to eq('failed')
    end

    it 'codes a character deleted since it was picked as character_missing' do
      first.destroy!

      described_class.perform_now(batch.id, 'preview')

      expect(reload_batch.item(first.id)).to include(status: 'failed', error_code: 'character_missing', error_status: nil,
                                                     error: 'This character no longer exists')
      expect(reload_batch.item(second.id)[:status]).to eq('previewed')
    end

    it 'does nothing for an expired refresh' do
      id = batch.id
      CharacterSkills::RefreshStore.clear
      expect { described_class.perform_now(id, 'preview') }.not_to raise_error
    end
  end

  describe 'apply' do
    before { described_class.perform_now(batch.id, 'preview') }

    it 'writes the chosen characters and skips the other previewed ones' do
      reload_batch.start_apply!([second.id])
      described_class.perform_now(batch.id, 'apply')

      state = reload_batch
      expect(state.status).to eq('applied')
      expect(state.item(first.id)[:status]).to eq('skipped')
      expect(state.item(second.id)).to include(status: 'applied', error: nil)
      expect(state.item(second.id)[:refresh][:written]).to be(true)
      expect(second.reload.wiki_raw).to eq(wiki(4))
      expect(first.reload.wiki_raw).to eq(wiki(7))
    end

    it 'codes a character deleted before the apply as character_missing' do
      reload_batch.start_apply!(nil)
      Character.without_skill_build { first.destroy! }

      described_class.perform_now(batch.id, 'apply')

      expect(reload_batch.item(first.id)).to include(status: 'failed', error_code: 'character_missing')
      expect(reload_batch.item(second.id)[:status]).to eq('applied')
    end

    it "marks a character failed when its previewed text has expired" do
      reload_batch.start_apply!(nil)
      CharacterSkills::RefreshStore.delete("batch:#{batch.id}:sources:#{first.id}")

      described_class.perform_now(batch.id, 'apply')

      state = reload_batch
      expect(state.item(first.id)).to include(status: 'failed', error: CharacterSkills::Refresh::EXPIRED_MESSAGE,
                                              error_code: 'preview_expired', error_status: nil)
      expect(state.item(second.id)[:status]).to eq('applied')
      expect(first.reload.wiki_raw).to eq(wiki(7))
    end
  end
end
