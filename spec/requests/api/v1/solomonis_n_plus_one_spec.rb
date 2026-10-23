# frozen_string_literal: true

require 'rails_helper'

# The full party view renders the Solomonis expedition: blessings with their
# levels, and guidebook entries with their guide effects. Grid position and
# swap actions render that view, so they must build it from a preloaded party
# or each blessing and guidebook entry costs extra queries.
RSpec.describe 'Solomonis full-party responses N+1', type: :request do
  let(:user) { create(:user) }
  let(:access_token) do
    Doorkeeper::AccessToken.create!(resource_owner_id: user.id, expires_in: 30.days, scopes: 'public')
  end
  let(:headers) do
    { 'Authorization' => "Bearer #{access_token.token}", 'Content-Type' => 'application/json' }
  end

  def build_run(entries)
    party = create(:party, :solomonis, user: user)
    entries.times do
      level = create(:arcarum_blessing_level, cost: 1)
      create(:party_blessing, party: party, arcarum_blessing_level: level)
      create(:expedition_guide_effect, party: party, solomonis_guide_effect: create(:solomonis_guide_effect))
    end
    weapons = [0, 2].map { |pos| create(:grid_weapon, party: party, position: pos) }
    [party, weapons]
  end

  def count_queries
    count = 0
    sub = ActiveSupport::Notifications.subscribe('sql.active_record') do |*, payload|
      next if payload[:cached] || %w[SCHEMA TRANSACTION].include?(payload[:name])

      count += 1
    end
    yield
    count
  ensure
    ActiveSupport::Notifications.unsubscribe(sub)
  end

  def swap_queries(entries)
    party, (source, target) = build_run(entries)
    queries = count_queries do
      post "/api/v1/parties/#{party.id}/grid_weapons/swap",
           params: { source_id: source.id, target_id: target.id }.to_json,
           headers: headers
    end
    expect(response).to have_http_status(:ok)
    solomonis = response.parsed_body.dig('party', 'solomonis')
    expect(solomonis['blessings'].size).to eq(entries)
    expect(solomonis['guidebook'].size).to eq(entries)
    queries
  end

  it 'runs the same number of queries for one blessing and guidebook entry as for several' do
    swap_queries(1) # warm-up: the first request runs one-off lookups
    one = swap_queries(1)
    several = swap_queries(5)

    expect(several).to eq(one)
  end
end
