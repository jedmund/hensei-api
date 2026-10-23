# frozen_string_literal: true

require 'rails_helper'

# Sticker fields on the party blueprint (labels, my_sticker,
# placed_stickers, sticker_breakdown) and the explore label param.
RSpec.describe 'Party sticker fields', type: :request do
  let(:owner) { create(:user) }
  let(:viewer) { create(:user) }
  let!(:party) { listable(create(:party, user: owner, visibility: 1)) }
  let!(:cleared) { create(:sticker, slug: 'cleared', position: 0) }
  let!(:fast) { create(:sticker, slug: 'fast', position: 1) }
  let!(:accessible) { create(:sticker, slug: 'accessible', position: 2) }

  def json_response
    JSON.parse(response.body)
  end

  # The explore list hides parties below the default grid counts.
  def listable(party)
    party.update_columns(weapons_count: 5, summons_count: 2, characters_count: 0)
    party
  end

  def give(count, sticker, to: party)
    create_list(:party_sticker, count, party: to, sticker: sticker)
  end

  def listed(id)
    json_response['results'].find { |p| p['id'] == id }
  end

  describe 'labels' do
    it 'shows the one sticker given most recently most' do
      give(2, cleared)
      give(3, fast)
      give(1, accessible)
      get '/api/v1/parties'
      expect(listed(party.id)['labels']).to eq(%w[fast])
    end

    it 'labels from a single giver' do
      give(1, cleared)
      get '/api/v1/parties'
      expect(listed(party.id)['labels']).to eq(%w[cleared])
    end

    it 'does not label without stickers' do
      get '/api/v1/parties'
      expect(listed(party.id)['labels']).to eq([])
    end

    it 'does not label with inactive stickers' do
      give(6, cleared)
      cleared.update!(active: false)
      get '/api/v1/parties'
      expect(listed(party.id)['labels']).to eq([])
    end

    it 'shows labels on the party page' do
      give(1, cleared)
      get "/api/v1/parties/#{party.shortcode}"
      expect(json_response['party']['labels']).to eq(['cleared'])
    end
  end

  describe 'my_sticker' do
    before { create(:party_sticker, party: party, sticker: fast, user: viewer) }

    it "is the viewer's sticker on lists and the party page" do
      get '/api/v1/parties', headers: bearer_headers(viewer)
      expect(listed(party.id)['my_sticker']).to eq('fast')

      get "/api/v1/parties/#{party.shortcode}", headers: bearer_headers(viewer)
      expect(json_response['party']['my_sticker']).to eq('fast')
    end

    it 'stays visible after the sticker is retired' do
      fast.update!(active: false)
      get "/api/v1/parties/#{party.shortcode}", headers: bearer_headers(viewer)
      expect(json_response['party']['my_sticker']).to eq('fast')
    end

    it 'is null when signed out' do
      get '/api/v1/parties'
      expect(listed(party.id)['my_sticker']).to be_nil
    end
  end

  describe 'placed_stickers' do
    it 'lists every active sticker given, oldest first, without saying who gave it' do
      first = create(:party_sticker, party: party, sticker: fast, x: 0.5, y: 20, rotation: -4, created_at: 2.days.ago)
      create(:party_sticker, party: party, sticker: cleared, user: viewer, created_at: 1.day.ago)
      retired = create(:sticker, slug: 'retired', position: 3, active: false)
      give(1, retired)

      get "/api/v1/parties/#{party.shortcode}", headers: bearer_headers(viewer)
      placed = json_response['party']['placed_stickers']
      expect(placed.map { |p| p['sticker'] }).to eq(%w[fast cleared])
      expect(placed.first).to eq('id' => first.id, 'sticker' => 'fast', 'mine' => false,
                                 'placement' => { 'x' => 0.5, 'y' => 20.0, 'rotation' => -4.0 })
      expect(placed.last).to include('mine' => true, 'placement' => nil)
      expect(placed.first.keys).not_to include('user_id')
    end

    it 'is not on list views' do
      give(1, cleared)
      get '/api/v1/parties'
      expect(listed(party.id)).not_to have_key('placed_stickers')
    end
  end

  describe 'sticker_breakdown' do
    before do
      give(2, cleared)
      give(1, fast)
      fast.update!(active: false)
    end

    it 'shows counts, including retired stickers, to the owner only' do
      get "/api/v1/parties/#{party.shortcode}", headers: bearer_headers(owner)
      expect(json_response['party']['sticker_breakdown']).to eq(
        [{ 'sticker' => 'cleared', 'count' => 2, 'meaning' => { 'en' => cleared.meaning_en, 'ja' => cleared.meaning_jp },
           'image_url' => nil, 'image_url_ja' => nil },
         { 'sticker' => 'fast', 'count' => 1, 'meaning' => { 'en' => fast.meaning_en, 'ja' => fast.meaning_jp },
           'image_url' => nil, 'image_url_ja' => nil }]
      )
    end

    it 'is absent for other viewers and signed-out visitors' do
      get "/api/v1/parties/#{party.shortcode}", headers: bearer_headers(viewer)
      expect(json_response['party']).not_to have_key('sticker_breakdown')

      get "/api/v1/parties/#{party.shortcode}"
      expect(json_response['party']).not_to have_key('sticker_breakdown')
    end

    it 'is absent on list pages' do
      get '/api/v1/parties', headers: bearer_headers(owner)
      expect(listed(party.id)).not_to have_key('sticker_breakdown')
    end
  end

  describe 'GET /api/v1/parties label' do
    let!(:low) { listable(create(:party, visibility: 1)) }
    let!(:high) { listable(create(:party, visibility: 1)) }

    it 'filters by label' do
      give(2, cleared, to: low)
      give(1, cleared, to: high)
      give(2, fast, to: high)
      get '/api/v1/parties', params: { label: 'cleared' }
      expect(json_response['results'].map { |p| p['id'] }).to eq([low.id])
    end
  end

  describe 'N+1' do
    def party_sticker_queries
      queries = []
      sub = ActiveSupport::Notifications.subscribe('sql.active_record') do |*, payload|
        queries << payload[:sql] if payload[:sql].include?('FROM "party_stickers"')
      end
      yield
      queries
    ensure
      ActiveSupport::Notifications.unsubscribe(sub)
    end

    it 'runs one labels query and one my_sticker query per page' do
      4.times { give(2, cleared, to: listable(create(:party, visibility: 1))) }

      queries = party_sticker_queries { get '/api/v1/parties', headers: bearer_headers(viewer) }

      expect(response).to have_http_status(:ok)
      expect(queries.size).to eq(2)
    end
  end
end
