# frozen_string_literal: true

require 'rails_helper'

# Responses are rendered two ways: Blueprinter strings and `render json:` with
# a hash (Rails' encoder). Both must format values identically, and timestamps
# must be ISO 8601 so every browser (including Safari) can parse them.
RSpec.describe 'JSON response format', type: :request do
  let(:iso8601_ms) { /\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}(Z|[+-]\d{2}:\d{2})\z/ }

  it 'generates the same JSON through Blueprinter as through the Rails encoder' do
    time = Time.utc(2026, 10, 1, 12, 34, 56, 789_000)
    payload = { at: time, nested: { computed_at: time, list: [time] }, date: Date.new(2026, 10, 1),
                amount: BigDecimal('1.50'), html: '<b>&</b>' }

    expect(Blueprinter.configuration.jsonify(payload)).to eq(ActiveSupport::JSON.encode(payload))
    expect(JSON.parse(Blueprinter.configuration.jsonify(payload))['nested']['computed_at'])
      .to eq('2026-10-01T12:34:56.789Z')
  end

  it 'returns ISO 8601 timestamps in a party response' do
    party = create(:party, visibility: 1)

    get "/api/v1/parties/#{party.shortcode}"

    expect(response).to have_http_status(:ok)
    body = response.parsed_body['party']
    expect(body['created_at']).to match(iso8601_ms)
    expect(body['updated_at']).to match(iso8601_ms)
  end
end
