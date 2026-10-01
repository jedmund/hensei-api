# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'robots.txt', type: :request do
  it 'disallows all crawling of the API' do
    get '/robots.txt'

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq('text/plain')
    expect(response.body).to eq("User-agent: *\nDisallow: /\n")
  end
end
