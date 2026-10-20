# frozen_string_literal: true

require 'rails_helper'

# Contract C6 (PR 5): the batch refresh after a balance patch. No network: the fetcher is stubbed.
RSpec.describe 'Character skill refreshes', type: :request do
  include ActiveJob::TestHelper

  let(:editor) { create(:user, role: 7) }
  let(:other_editor) { create(:user, role: 7) }
  let(:user) { create(:user, role: 1) }

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
      create(:character, granblue_id: granblue_id, element: 2, wiki_en: "Page #{granblue_id}", wiki_raw: wiki(7), **attrs)
    end
  end

  let!(:first) { make('3040900001', name_en: 'First', name_jp: '一') }
  let!(:style) do
    make('3040900001', name_en: 'First', style_swap: true, style_name_en: 'Super First', style_name_jp: nil)
  end
  let!(:second) { make('3040900002', name_en: 'Second') }

  def auth_headers(account)
    token = Doorkeeper::AccessToken.create!(resource_owner_id: account.id, expires_in: 30.days, scopes: 'public')
    { 'Authorization' => "Bearer #{token.token}", 'Content-Type' => 'application/json' }
  end

  def create_refresh(ids, as: editor, refetch_jp: false)
    post '/api/v1/character_skill_refreshes', params: { character_ids: ids, refetch_jp: refetch_jp }.to_json,
                                              headers: auth_headers(as)
  end

  def show(id, as: editor)
    get "/api/v1/character_skill_refreshes/#{id}", headers: auth_headers(as)
  end

  def apply(id, body = {}, as: editor)
    post "/api/v1/character_skill_refreshes/#{id}/apply", params: body.to_json, headers: auth_headers(as)
  end

  def cooldown(character)
    CharacterSkillVersion.joins(:character_skill).find_by(character_skills: { character_id: character.id }).cooldown
  end

  before do
    CharacterSkills::RefreshStore.clear
    allow(CharacterSkills::WikiPacer.instance).to receive(:wait)
    # The rebalance: every page's cooldown drops to 5.
    allow_any_instance_of(Granblue::WikiFetcher).to receive(:fetch) do |_, entity, **|
      Granblue::WikiFetcher::Page.new(title: entity.wiki_en, text: wiki(5))
    end
    CharacterSkills::Build::Runner.new(mode: 'write', all: true, io: StringIO.new, enqueue_icons: false).call
  end

  describe 'POST /character_skill_refreshes' do
    it 'queues the refresh and lists the characters in the order picked' do
      create_refresh([second.id, style.id])
      expect(response).to have_http_status(:accepted)
      id = response.parsed_body['id']
      expect(id).to match(/\Arf_\h{32}\z/)
      expect(CharacterSkills::RefreshJob).to have_been_enqueued.with(id, 'preview')

      show(id)
      body = response.parsed_body
      expect(body).to include('id' => id, 'status' => 'queued', 'refetch_jp' => false, 'created_at' => be_present)
      expect(body).not_to have_key('user_id')
      expect(body['items']).to eq([
        { 'character_id' => second.id, 'granblue_id' => '3040900002', 'style_swap' => false,
          'name' => { 'en' => 'Second', 'ja' => second.name_jp }, 'style_name' => nil,
          'status' => 'queued', 'error' => nil, 'refresh' => nil },
        { 'character_id' => style.id, 'granblue_id' => '3040900001', 'style_swap' => true,
          'name' => { 'en' => 'First', 'ja' => style.name_jp }, 'style_name' => { 'en' => 'Super First', 'ja' => nil },
          'status' => 'queued', 'error' => nil, 'refresh' => nil }
      ])
    end

    it 'is a 422 too_many_characters over 20' do
      ids = Array.new(21) { |i| make("30409100#{i.to_s.rjust(2, '0')}").id }
      create_refresh(ids)
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body).to include('error' => 'too_many_characters', 'message' => be_present)
      expect(CharacterSkills::RefreshJob).not_to have_been_enqueued
    end

    it 'is a 422 for no or unknown characters' do
      create_refresh([])
      expect(response).to have_http_status(:unprocessable_entity)
      create_refresh([first.id, SecureRandom.uuid, 'nope'])
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'rejects non-editors' do
      create_refresh([first.id], as: user)
      expect(response).to have_http_status(:unauthorized)
    end

    it 'is a 429 after five an hour per editor' do
      5.times do
        create_refresh([first.id])
        expect(response).to have_http_status(:accepted)
      end
      create_refresh([first.id])
      expect(response).to have_http_status(:too_many_requests)

      create_refresh([first.id], as: other_editor)
      expect(response).to have_http_status(:accepted)
    end
  end

  describe 'GET /character_skill_refreshes/:id' do
    it "is a 404 for someone else's refresh, or an unknown one" do
      create_refresh([first.id])
      id = response.parsed_body['id']

      show(id, as: other_editor)
      expect(response).to have_http_status(:not_found)
      apply(id, {}, as: other_editor)
      expect(response).to have_http_status(:not_found)
      show('rf_unknown')
      expect(response).to have_http_status(:not_found)
    end

    it 'rejects non-editors' do
      show('rf_unknown', as: user)
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'preview, then apply the chosen characters' do
    it 'writes the chosen characters from the previewed text and skips the rest' do
      create_refresh([first.id, style.id, second.id])
      id = response.parsed_body['id']
      perform_enqueued_jobs

      show(id)
      body = response.parsed_body
      expect(body['status']).to eq('previewed')
      expect(body['items'].pluck('status')).to all(eq('previewed'))
      refresh = body['items'].first['refresh']
      expect(refresh).to include('written' => false, 'wiki_changed' => true, 'preview_token' => nil)
      expect(refresh['changes']).to include(a_hash_including('kind' => 'ability', 'change' => 'updated',
                                                             'fields' => include('cooldown')))
      expect(first.reload.wiki_raw).to eq(wiki(7))
      expect(cooldown(first)).to eq(7)

      # The pages change again after the preview; the apply must not refetch.
      allow_any_instance_of(Granblue::WikiFetcher).to receive(:fetch).and_raise('no refetch on apply')

      apply(id, { character_ids: [first.id, second.id] })
      expect(response).to have_http_status(:accepted)
      show(id)
      expect(response.parsed_body['status']).to eq('applying')

      perform_enqueued_jobs
      show(id)
      body = response.parsed_body
      expect(body['status']).to eq('applied')
      expect(body['items'].to_h { |item| [item['character_id'], item['status']] })
        .to eq(first.id => 'applied', style.id => 'skipped', second.id => 'applied')
      expect(body['items'].first['refresh']).to include('written' => true)

      expect(first.reload).to have_attributes(wiki_raw: wiki(5), wiki_raw_fetched_at: be_present)
      expect(cooldown(first)).to eq(5)
      expect(cooldown(second)).to eq(5)
      expect(style.reload.wiki_raw).to eq(wiki(7))
      expect(cooldown(style)).to eq(7)
      expect(CharacterSkills::BuildJob).not_to have_been_enqueued
    end

    it 'applies every previewed character by default' do
      create_refresh([first.id, second.id])
      id = response.parsed_body['id']
      perform_enqueued_jobs
      apply(id)
      perform_enqueued_jobs

      show(id)
      expect(response.parsed_body['items'].pluck('status')).to eq(%w[applied applied])
    end

    it 'is a 409 before the preview has finished' do
      create_refresh([first.id])
      apply(response.parsed_body['id'])
      expect(response).to have_http_status(:conflict)
    end
  end
end
