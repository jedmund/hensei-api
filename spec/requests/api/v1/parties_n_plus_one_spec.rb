# frozen_string_literal: true

require 'rails_helper'

# Regression for the N+1 Sentry caught in PartiesController#update: rendering the
# full PartyBlueprint over a non-eager-loaded party ran a summon (+ series +
# substitution + collection) query per grid item. update and grid_update now
# re-fetch through load_full_party, which eager-loads everything.
RSpec.describe 'Api::V1::Parties N+1', type: :request do
  let(:user) { create(:user) }
  let(:access_token) do
    Doorkeeper::AccessToken.create!(resource_owner_id: user.id, expires_in: 30.days, scopes: 'public')
  end
  let(:headers) do
    { 'Authorization' => "Bearer #{access_token.token}", 'Content-Type' => 'application/json' }
  end

  # Collects single-row `summons WHERE id = ?` SELECTs run during the block —
  # the signature of the per-grid-summon N+1. Eager loading uses `WHERE id IN
  # (...)` instead, so this should be empty once the response is preloaded.
  def per_summon_id_queries
    queries = []
    sub = ActiveSupport::Notifications.subscribe('sql.active_record') do |*, payload|
      sql = payload[:sql]
      queries << sql if sql.include?('FROM "summons"') && sql.include?('"summons"."id" =')
    end
    yield
    queries
  ensure
    ActiveSupport::Notifications.unsubscribe(sub)
  end

  it 'does not run a query per grid summon when rendering the update response' do
    party = create(:party, user: user)
    # Distinct summons so the eager-load batches them into one `WHERE id IN`,
    # while the unfixed N+1 would emit one `WHERE id = ?` per grid summon.
    4.times { |i| create(:grid_summon, party: party, position: i, summon: create(:summon)) }

    queries = per_summon_id_queries do
      put "/api/v1/parties/#{party.id}",
          params: { party: { name: 'Renamed' } }.to_json,
          headers: headers
    end

    expect(response).to have_http_status(:ok)
    expect(queries.size).to eq(0),
                            "expected no per-summon SELECTs during render, got #{queries.size}:\n#{queries.join("\n")}"
  end
end
