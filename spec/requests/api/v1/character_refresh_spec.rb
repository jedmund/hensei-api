# frozen_string_literal: true

require 'rails_helper'

# Contract C6 (PR 5): an editor refreshes a rebalanced character from the wiki with a
# preview first. No network: the fetchers are stubbed.
RSpec.describe 'Character refresh (C6)', type: :request do
  include ActiveJob::TestHelper

  let(:editor) { create(:user, role: 7) }
  let(:other_editor) { create(:user, role: 7) }
  let(:user) { create(:user, role: 1) }
  let(:fixtures) { Rails.root.join('spec/fixtures/character_skills') }
  let(:stored_text) { fixtures.join('character-vikala-wikidata.txt').read }
  # The rebalance: Ring the Dormouse's cooldown drops from 11 to 9.
  let(:fetched_text) { stored_text.sub('cooldown=11|', 'cooldown=9|') }
  let(:character) do
    Character.without_skill_build do
      create(:character, granblue_id: '3040252000', name_en: 'Vikala', wiki_en: 'Vikala', wiki_raw: stored_text,
                         game_raw_en: JSON.parse(fixtures.join('character-vikala-gamedata.json').read))
    end
  end

  def auth_headers(account)
    token = Doorkeeper::AccessToken.create!(resource_owner_id: account.id, expires_in: 30.days, scopes: 'public')
    { 'Authorization' => "Bearer #{token.token}", 'Content-Type' => 'application/json' }
  end

  def stub_wiki(text, title: 'Vikala')
    allow_any_instance_of(Granblue::WikiFetcher).to receive(:fetch) do |_, _entity, **|
      Granblue::WikiFetcher::Page.new(title: title, text: text)
    end
  end

  def reparse(body, as: editor)
    post "/api/v1/characters/#{character.id}/reparse", params: body.to_json, headers: auth_headers(as)
  end

  def preview(**body)
    reparse({ refetch: true, refetch_jp: false, preview: true, preview_token: nil }.merge(body))
    response.parsed_body
  end

  def apply(token, as: editor)
    reparse({ refetch: false, refetch_jp: false, preview: false, preview_token: token }, as: as)
  end

  def versions
    CharacterSkillVersion.joins(:character_skill).where(character_skills: { character_id: character.id })
                         .order(:id).map { |v| v.attributes.except('updated_at') }
  end

  def ring_cooldown
    CharacterSkillVersion.joins(:character_skill)
                         .find_by(character_skills: { character_id: character.id }, name_en: 'Ring the Dormouse', ordinal: 1)
                         .cooldown
  end

  before do
    CharacterSkills::RefreshStore.clear
    allow(CharacterSkills::WikiPacer.instance).to receive(:wait)
    # The skills as built from the stored text.
    CharacterSkills::Build::Runner.new(mode: 'write', characters: [character], all: true, io: StringIO.new,
                                       enqueue_icons: false).call
    character.reload
    clear_enqueued_jobs
  end

  describe 'POST /characters/:id/reparse with preview' do
    before { stub_wiki(fetched_text) }

    it 'shows what would change and writes nothing' do
      before_versions = versions
      fingerprint = character.character_skill_build_fingerprint
      statuses = Status.count

      body = preview
      expect(response).to have_http_status(:ok)
      refresh = body['refresh']
      expect(refresh).to include('written' => false, 'wiki_changed' => true, 'wiki_jp_changed' => nil)
      expect(refresh['preview_token']).to match(/\Apv_\h{32}\z/)
      expect(refresh['fetched_at']).to be_present
      expect(refresh['counts'].keys).to match_array(CharacterSkills::Refresh::COUNTS.map(&:to_s))
      expect(refresh['counts']['versions_updated']).to be >= 1
      expect(refresh['changes']).to include(
        a_hash_including('kind' => 'ability', 'position' => 1, 'ordinal' => 1, 'change' => 'updated',
                         'name' => { 'en' => 'Ring the Dormouse', 'ja' => anything },
                         'fields' => include('cooldown'))
      )
      expect(body['character']).to be_nil

      character.reload
      expect(character.wiki_raw).to eq(stored_text)
      expect(character.wiki_raw_fetched_at).to be_nil
      expect(character.character_skill_build_fingerprint).to eq(fingerprint)
      expect(versions).to eq(before_versions)
      expect(Status.count).to eq(statuses)
      expect(enqueued_jobs).to be_empty
    end

    it 'says nothing changed when the wikitext is the same' do
      stub_wiki(stored_text)
      refresh = preview['refresh']
      expect(refresh).to include('wiki_changed' => false, 'changes' => [])
      expect(refresh['counts'].values).to all(eq(0))
    end

    it 'fetches the Japanese page too when asked' do
      allow_any_instance_of(Granblue::Downloaders::JpWikiDownloader).to receive(:fetch).and_return('<html>jp</html>')
      refresh = preview(refetch_jp: true)['refresh']
      expect(refresh['wiki_jp_changed']).to be(true)
      expect(character.reload.wiki_raw_jp).to be_nil
    end

    it 'reports versions whose icon falls back to the wiki stem' do
      allow_any_instance_of(Granblue::Parsers::CharacterSkills::Builder).to receive(:game_icon_for)
        .and_return({ game_icon: '9999_1', game_icon_source: 'wiki' })
      refresh = preview['refresh']
      expect(refresh['icon_fallbacks']).to include(
        { 'kind' => 'ability', 'position' => 1, 'ordinal' => 1, 'name' => { 'en' => 'Ring the Dormouse', 'ja' => anything } }
      )
    end

    it 'rejects non-editors' do
      reparse({ refetch: true, preview: true }, as: user)
      expect(response).to have_http_status(:unauthorized)
    end

    it 'is a 502 when the wiki fails' do
      allow_any_instance_of(Granblue::WikiFetcher).to receive(:fetch)
        .and_raise(Granblue::WikiError.new(code: 502, message: 'Server error', page: 'Vikala'))
      preview
      expect(response).to have_http_status(:bad_gateway)
    end

    it 'is a 502, not a 500, when the wiki times out' do
      allow_any_instance_of(Granblue::WikiFetcher).to receive(:fetch).and_call_original
      stub_request(:get, %r{\Ahttps://gbf\.wiki/api\.php}).to_timeout
      preview
      expect(response).to have_http_status(:bad_gateway)
      expect(a_request(:get, %r{\Ahttps://gbf\.wiki/api\.php})).to have_been_made
    end
  end

  describe 'POST /characters/:id/reparse with a preview token' do
    it 'writes exactly the previewed text, without fetching again' do
      stub_wiki(fetched_text, title: 'Vikala (Renamed)')
      token = preview['refresh']['preview_token']
      stub_wiki(stored_text.sub('cooldown=11|', 'cooldown=5|'))

      apply(token)
      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body['refresh']).to include('written' => true, 'wiki_changed' => true, 'preview_token' => nil)
      expect(body['character']).to include('id' => character.id)

      character.reload
      expect(character.wiki_raw).to eq(fetched_text)
      expect(character.wiki_en).to eq('Vikala (Renamed)')
      expect(character.wiki_raw_fetched_at).to be_present
      expect(character.character_skill_build_fingerprint).to be_present
      expect(ring_cooldown).to eq(9)
      expect(enqueued_jobs.map { |job| job['job_class'] }).not_to include('CharacterSkills::BuildJob')
    end

    it 'writes the Japanese page when it was previewed' do
      stub_wiki(fetched_text)
      allow_any_instance_of(Granblue::Downloaders::JpWikiDownloader).to receive(:fetch).and_return('<html>jp</html>')
      token = preview(refetch_jp: true)['refresh']['preview_token']
      apply(token)
      expect(response.parsed_body['refresh']['wiki_jp_changed']).to be(true)
      expect(character.reload).to have_attributes(wiki_raw_jp: '<html>jp</html>', wiki_raw_jp_fetched_at: be_present)
    end

    it 'is a 422 preview_expired once the token has expired' do
      stub_wiki(fetched_text)
      token = preview['refresh']['preview_token']
      travel 31.minutes do
        apply(token)
      end
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body).to include('error' => 'preview_expired', 'message' => be_present)
      expect(character.reload.wiki_raw).to eq(stored_text)
    end

    it 'is a 422 preview_expired for an unknown or used token' do
      apply('pv_unknown')
      expect(response.parsed_body['error']).to eq('preview_expired')

      stub_wiki(fetched_text)
      token = preview['refresh']['preview_token']
      apply(token)
      expect(response).to have_http_status(:ok)
      apply(token)
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "is a 422 for someone else's preview" do
      stub_wiki(fetched_text)
      token = preview['refresh']['preview_token']
      apply(token, as: other_editor)
      expect(response).to have_http_status(:unprocessable_entity)
      expect(character.reload.wiki_raw).to eq(stored_text)
    end

    it "is a 422 for another character's preview" do
      stub_wiki(fetched_text)
      token = preview['refresh']['preview_token']
      other = Character.without_skill_build { create(:character, wiki_raw: stored_text) }
      post "/api/v1/characters/#{other.id}/reparse", params: { preview: false, preview_token: token }.to_json,
                                                     headers: auth_headers(editor)
      expect(response).to have_http_status(:unprocessable_entity)
      expect(other.reload.wiki_raw).to eq(stored_text)
    end

    it "is a 422 when the character's other inputs changed since the preview" do
      stub_wiki(fetched_text)
      token = preview['refresh']['preview_token']
      character.update_columns(element: 2)
      apply(token)
      expect(response.parsed_body['error']).to eq('preview_expired')
      expect(character.reload.wiki_raw).to eq(stored_text)
    end
  end

  describe 'POST /characters/:id/reparse without a preview' do
    it 'fetches, writes and builds, and returns the character' do
      stub_wiki(fetched_text)
      post "/api/v1/characters/#{character.id}/reparse?refetch=true", headers: auth_headers(editor)
      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body['refresh']).to include('written' => true, 'wiki_changed' => true)
      expect(body['character']).to include('id' => character.id)
      expect(character.reload.wiki_raw).to eq(fetched_text)
      expect(ring_cooldown).to eq(9)
    end

    # The stored row already has a fetch time (every row in prod does); the refresh's
    # fetched_at is an ISO string.
    it 'dates an unchanged page as fetched again' do
      Source.owned_by(character).update_all(fetched_at: 1.week.ago)
      stub_wiki(stored_text)
      post "/api/v1/characters/#{character.id}/reparse?refetch=true", headers: auth_headers(editor)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['refresh']).to include('written' => true, 'wiki_changed' => false)
      expect(character.reload.wiki_raw_fetched_at).to be > 1.minute.ago
    end

    it 'rebuilds from the stored text without fetching' do
      expect_any_instance_of(Granblue::WikiFetcher).not_to receive(:fetch)
      reparse({ refetch: false, refetch_jp: false, preview: false, preview_token: nil })
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['refresh']).to include('written' => true, 'wiki_changed' => false, 'changes' => [],
                                                         'fetched_at' => nil)
    end
  end

  describe 'POST /characters/:id/reparse while another build is running' do
    include BuildLockHelpers

    before do
      stub_wiki(fetched_text)
      stub_const('CharacterSkills::Refresh::LOCK_WAIT', 0.2)
    end

    let(:busy) { CharacterSkills::Refresh::BUSY_MESSAGE }

    it 'is a 422 with the build refusal shape for a preview' do
      held_elsewhere(:character, character.id) { preview }
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body).to eq('error' => busy, 'message' => busy)
    end

    it 'is a 422 and writes nothing for an apply' do
      token = preview['refresh']['preview_token']
      before_versions = versions
      held_elsewhere(:all) { apply(token) }
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['message']).to eq(busy)
      expect(versions).to eq(before_versions)
      expect(character.reload.wiki_raw).to eq(stored_text)
    end

    it 'waits for a build that finishes in time, then writes' do
      stub_const('CharacterSkills::Refresh::LOCK_WAIT', 5.seconds)
      held_elsewhere(:character, character.id, release_after: 0.3) do
        post "/api/v1/characters/#{character.id}/reparse?refetch=true", headers: auth_headers(editor)
      end
      expect(response).to have_http_status(:ok)
      expect(ring_cooldown).to eq(9)
    end

    it 'runs alongside a build of another character' do
      held_elsewhere(:character, 'another') { preview }
      expect(response).to have_http_status(:ok)
    end
  end
end
