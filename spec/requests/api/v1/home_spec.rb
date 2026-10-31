# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::Home', type: :request do
  let(:raid) { create(:raid) }
  let(:empty_raid) { create(:raid) }
  let!(:sticker) { create(:sticker, slug: 'full-auto') }
  let!(:other_sticker) { create(:sticker, slug: 'fast') }

  def json_response
    JSON.parse(response.body)
  end

  def give(party, sticker:, by: trusted_user, at: 1.day.ago)
    create(:party_sticker, party: party, sticker: sticker, user: by, created_at: at)
  end

  describe 'GET /api/v1/home' do
    let!(:current) { create(:event, :current, created_at: 3.days.ago) }
    let!(:top) { create(:party, raid: raid, visibility: 1) }
    let!(:second) { create(:party, raid: raid, visibility: 1) }
    let!(:private_party) { create(:party, raid: raid, visibility: 3) }

    before do
      create(:event_raid, event: current, raid: raid, position: 0)
      create(:event_raid, event: current, raid: empty_raid, position: 1)
      2.times { give(top, sticker: sticker) }
      give(second, sticker: other_sticker)
      give(private_party, sticker: sticker)
    end

    it 'ranks public parties per raid for current events and keeps empty raids' do
      get '/api/v1/home'

      expect(response).to have_http_status(:ok)
      section = json_response['current'].sole
      expect(section['event']['id']).to eq(current.id)
      expect(section['raids'].map { |r| r['raid']['id'] }).to eq([raid.id, empty_raid.id])
      expect(section['raids'].first['raid']['slug']).to eq(raid.slug)
      expect(section['raids'].first['parties'].map { |p| p['id'] }).to eq([top.id, second.id])
      expect(section['raids'].second['parties']).to eq([])
    end

    it 'fills in my_sticker for the signed-in viewer' do
      viewer = create(:user)
      give(second, sticker: sticker, by: viewer)
      get '/api/v1/home', headers: bearer_headers(viewer)

      parties = json_response['current'].sole['raids'].first['parties'].index_by { |p| p['id'] }
      expect(parties[second.id]['my_sticker']).to eq('full-auto')
      expect(parties[top.id]['my_sticker']).to be_nil
    end

    it 'lists rising parties by stored score, at most 9, with last_updated' do
      PartyParticipation::Persister.call([top.id, second.id, private_party.id])
      10.times { create(:party, visibility: 1).update_columns(participation_score: 0.01) }

      get '/api/v1/home'

      rising = json_response['rising']
      expect(rising.size).to eq(9)
      expect(rising.first['id']).to eq(top.id)
      expect(rising.map { |p| p['id'] }).not_to include(private_party.id)
      expect(rising.first).to have_key('last_updated')
    end

    it 'ranks newer teams above older ones with the same score' do
      old = create(:party, visibility: 1, created_at: 30.days.ago)
      newer = create(:party, visibility: 1, created_at: 2.days.ago)
      newest = create(:party, visibility: 1, created_at: 1.hour.ago)
      # Half the score of the others, but 30 days (two half-lives) older
      # loses to it by more than that
      old.update_columns(participation_score: 2.0)
      newer.update_columns(participation_score: 1.0)
      newest.update_columns(participation_score: 1.0)

      get '/api/v1/home'

      expect(json_response['rising'].map { |p| p['id'] }).to eq([newest.id, newer.id, old.id])
    end

    it 'hides Rising when fewer than 3 teams have a score' do
      2.times { create(:party, visibility: 1).update_columns(participation_score: 1.0) }
      create(:party, visibility: 1)

      get '/api/v1/home'

      expect(json_response['rising']).to eq([])
    end

    it 'never exposes participation scores' do
      PartyParticipation::Persister.call([top.id, second.id])
      get '/api/v1/home'
      expect(response.body).not_to include('participation')
    end
  end

  shared_examples 'advantage ordering' do |kind|
    let!(:gw) { create(:event, :current, kind, element: 'Water', created_at: 3.days.ago) }
    let!(:fire_party) { create(:party, raid: raid, visibility: 1) }
    let!(:earth_party) { create(:party, raid: raid, visibility: 1) }

    before do
      create(:event_raid, event: gw, raid: raid)
      fire_party.update_columns(element: GranblueEnums::ELEMENTS[:Fire])
      earth_party.update_columns(element: GranblueEnums::ELEMENTS[:Earth])
      3.times { give(fire_party, sticker: sticker) }
      give(earth_party, sticker: sticker)
    end

    it 'only shows parties of the element advantaged against the boss' do
      get '/api/v1/home'
      parties = json_response['current'].sole['raids'].sole['parties']
      expect(parties.map { |p| p['id'] }).to eq([earth_party.id])
    end
  end

  describe 'Unite and Fight ordering' do
    it_behaves_like 'advantage ordering', :unite_and_fight
  end

  describe 'Dread Barrage ordering' do
    it_behaves_like 'advantage ordering', :dread_barrage
  end

  describe 'non-themed events' do
    let!(:event) { create(:event, :current, kind: :farming, element: 'Water', created_at: 3.days.ago) }
    let!(:fire_party) { create(:party, raid: raid, visibility: 1) }
    let!(:earth_party) { create(:party, raid: raid, visibility: 1) }

    before do
      create(:event_raid, event: event, raid: raid)
      fire_party.update_columns(element: GranblueEnums::ELEMENTS[:Fire])
      earth_party.update_columns(element: GranblueEnums::ELEMENTS[:Earth])
      3.times { give(fire_party, sticker: sticker) }
      give(earth_party, sticker: sticker)
    end

    it 'orders by score only' do
      get '/api/v1/home'
      parties = json_response['current'].sole['raids'].sole['parties']
      expect(parties.map { |p| p['id'] }).to eq([fire_party.id, earth_party.id])
    end
  end

  describe 'upcoming events' do
    let!(:previous) { create(:event, :past, created_at: 45.days.ago) }
    let!(:upcoming) { create(:event, :upcoming) }
    let!(:far_future) { create(:event, starts_at: 30.days.from_now, ends_at: 37.days.from_now) }
    let!(:party) { create(:party, raid: raid, visibility: 1) }

    before do
      create(:event_raid, event: previous, raid: raid)
      create(:event_raid, event: upcoming, raid: raid)
      give(party, sticker: sticker, at: 36.days.ago)
    end

    it 'includes events starting within 14 days with the previous run and its top parties' do
      get '/api/v1/home'

      section = json_response['upcoming'].sole
      expect(section['event']['id']).to eq(upcoming.id)
      expect(section['previous_event']['id']).to eq(previous.id)
      expect(section['raids'].sole['parties'].map { |p| p['id'] }).to eq([party.id])
    end

    it 'caps upcoming at 3, soonest first' do
      starts = [5, 2, 7, 4].map { |d| create(:event, starts_at: d.days.from_now, ends_at: (d + 7).days.from_now) }
      get '/api/v1/home'
      ids = json_response['upcoming'].map { |s| s['event']['id'] }
      expect(ids.size).to eq(3)
      expect(ids).to eq([starts[1].id, upcoming.id, starts[3].id])
    end
  end

  describe 'staff picks' do
    let(:party) { create(:party, visibility: 1) }

    it 'shows eventless picks and picks for running or upcoming events' do
      running = create(:featured_party, party: party, event: create(:event, :current), position: 1)
      eventless = create(:featured_party, party: create(:party, visibility: 1), position: 0)
      create(:featured_party, party: create(:party, visibility: 1), event: create(:event, :past))
      create(:featured_party, party: create(:party, visibility: 1), event: create(:event, :current, :draft))
      hidden_party = create(:party, visibility: 1)
      create(:featured_party, party: hidden_party)
      hidden_party.update_columns(visibility: 3)

      get '/api/v1/home'

      picks = json_response['staff_picks']
      expect(picks.map { |p| p['id'] }).to eq([eventless.id, running.id])
      expect(picks.first['party']).to include('id' => eventless.party_id)
    end
  end

  describe 'new battles' do
    let!(:new_raid) { create(:raid, released_at: 10.days.ago.to_date) }
    let!(:old_raid) { create(:raid, released_at: 40.days.ago.to_date) }
    let!(:undated_raid) { create(:raid) }
    let!(:older_team) { create(:party, raid: new_raid, visibility: 1, created_at: 3.days.ago) }
    let!(:newer_team) { create(:party, raid: new_raid, visibility: 1, created_at: 1.day.ago) }

    before do
      create(:party, raid: new_raid, visibility: 3)
      create(:party, raid: old_raid, visibility: 1)
      older_team.update_columns(participation_score: 1.5)
    end

    it 'lists raids released in the last 4 weeks with their recent and trending teams' do
      get '/api/v1/home'

      battles = json_response['new_battles']
      expect(battles.map { |b| b['raid']['id'] }).to eq([new_raid.id])
      expect(battles.first['raid']).to include('slug' => new_raid.slug, 'released_at' => new_raid.released_at.iso8601)
      expect(battles.first['recent'].map { |p| p['id'] }).to eq([newer_team.id, older_team.id])
      expect(battles.first['trending'].map { |p| p['id'] }).to eq([older_team.id, newer_team.id])
    end

    it 'orders trending teams like Rising, so a newer team can outrank a higher score' do
      veteran = create(:party, raid: new_raid, visibility: 1, created_at: 30.days.ago)
      veteran.update_columns(participation_score: 2.0)
      newer_team.update_columns(participation_score: 1.0)
      older_team.update_columns(participation_score: 0)

      get '/api/v1/home'

      trending = json_response['new_battles'].first['trending'].map { |p| p['id'] }
      expect(trending).to eq([newer_team.id, veteran.id, older_team.id])
    end
  end

  describe 'new items' do
    let(:new_character) { create(:character, release_date: 3.days.ago.to_date) }
    let(:uncapped_character) do
      create(:character, release_date: 2.years.ago.to_date, flb_date: 5.days.ago.to_date)
    end
    let(:old_character) { create(:character, release_date: 30.days.ago.to_date) }

    def team_with(character, visibility: 1, made: 1.day.ago)
      party = create(:party, visibility: visibility)
      create(:grid_character, party: party, character: character, position: 0)
      party.update_columns(created_at: made, last_updated: 1.hour.ago)
      party
    end

    it 'lists items new in the last 18 days with teams made since, newest first' do
      newer = team_with(new_character)
      uncapped = team_with(uncapped_character)
      team_with(uncapped_character, made: 30.days.ago) # made before the uncap, edited since
      team_with(old_character)
      team_with(new_character, visibility: 3)

      get '/api/v1/home'
      items = json_response['new_items']

      expect(items.map { |entry| entry['item']['id'] }).to eq([new_character.id, uncapped_character.id])
      expect(items.first['item']).to include('type' => 'character', 'granblue_id' => new_character.granblue_id,
                                             'change' => 'release')
      expect(items.second['item']['change']).to eq('flb')
      expect(items.first['item']['character']).to include('element', 'season', 'series', 'style_swap')
      expect(items.first['parties'].map { |party| party['id'] }).to eq([newer.id])
      # Teams made before the uncap don't count, even if edited since
      expect(items.second['parties'].map { |party| party['id'] }).to eq([uncapped.id])
    end

    it 'includes new items nobody has used yet, with no teams' do
      new_character

      get '/api/v1/home'
      expect(json_response['new_items'].map { |entry| [entry['item']['id'], entry['parties']] })
        .to eq([[new_character.id, []]])
    end
  end
end
