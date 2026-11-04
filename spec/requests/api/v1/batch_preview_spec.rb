# frozen_string_literal: true

require 'rails_helper'

# POST /{characters,weapons,summons}/batch_preview (BatchPreviewable): fetches
# or takes each page's wikitext, follows a redirect, parses it and says
# whether the entity already exists.
RSpec.describe 'Batch wiki preview', type: :request do
  include CommunitySpecHelpers

  let(:editor) { create(:user, role: 7) }
  let(:wiki) { instance_double(Granblue::Parsers::Wiki) }
  let(:parser) { Granblue::Parsers::WikiDataParser }

  before { allow(Granblue::Parsers::Wiki).to receive(:new).and_return(wiki) }

  def preview(type, pages, wiki_data: nil)
    params = { wiki_pages: pages }
    params[:wiki_data] = wiki_data if wiki_data
    post "/api/v1/#{type}/batch_preview", params: params, headers: bearer_headers(editor), as: :json
  end

  it 'fetches, parses and marks a new character as pending' do
    allow(wiki).to receive(:fetch).with('Lyria').and_return('{{Character}}')
    allow(parser).to receive(:parse_character).with('{{Character}}').and_return({ granblue_id: '3990000000', name_en: 'Lyria' })

    preview('characters', ['Lyria'])

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to eq('results' => [{
                                         'wiki_page' => 'Lyria', 'status' => 'success', 'wiki_raw' => '{{Character}}',
                                         'granblue_id' => '3990000000',
                                         'parsed_data' => { 'granblue_id' => '3990000000', 'name_en' => 'Lyria' },
                                         'image_status' => 'pending'
                                       }])
  end

  it 'follows a redirect and reports where it came from' do
    allow(wiki).to receive(:fetch).with('Old Name').and_return('#REDIRECT [[New Name]]')
    allow(wiki).to receive(:fetch).with('New Name').and_return('{{Weapon}}')
    create(:weapon, granblue_id: '1040000001')
    allow(parser).to receive(:parse_weapon).with('{{Weapon}}').and_return({ granblue_id: '1040000001' })

    preview('weapons', ['Old Name'])

    expect(response.parsed_body['results']).to eq([{
                                                    'wiki_page' => 'New Name', 'status' => 'success',
                                                    'redirected_from' => 'Old Name', 'wiki_raw' => '{{Weapon}}',
                                                    'granblue_id' => '1040000001',
                                                    'parsed_data' => { 'granblue_id' => '1040000001' },
                                                    'image_status' => 'exists'
                                                  }])
  end

  it 'uses client-supplied wikitext without fetching or following redirects' do
    allow(parser).to receive(:parse_summon).with('#REDIRECT [[Elsewhere]]').and_return({})

    preview('summons', ['Bahamut'], wiki_data: { 'Bahamut' => '#REDIRECT [[Elsewhere]]' })

    expect(Granblue::Parsers::Wiki).not_to have_received(:new)
    expect(response.parsed_body['results']).to eq([{
                                                    'wiki_page' => 'Bahamut', 'status' => 'success',
                                                    'wiki_raw' => '#REDIRECT [[Elsewhere]]',
                                                    'parsed_data' => {}, 'image_status' => 'no_id'
                                                  }])
  end

  it 'reports a missing wiki page' do
    allow(wiki).to receive(:fetch).and_raise(Granblue::WikiError.new(message: 'Nope'))

    preview('characters', ['Missing'])

    expect(response.parsed_body['results']).to eq([{ 'wiki_page' => 'Missing', 'status' => 'error',
                                                     'error' => 'Wiki page not found: Nope' }])
  end

  it 'reports any other failure, keeping what it had' do
    allow(wiki).to receive(:fetch).and_return('text')
    allow(parser).to receive(:parse_character).and_raise(StandardError, 'bad parse')

    preview('characters', ['Broken'])

    expect(response.parsed_body['results']).to eq([{ 'wiki_page' => 'Broken', 'status' => 'error', 'wiki_raw' => 'text',
                                                     'error' => 'Failed to process wiki page: bad parse' }])
  end

  it 'previews at most 10 pages' do
    allow(wiki).to receive(:fetch).and_return('text')
    allow(parser).to receive(:parse_character).and_return({})

    preview('characters', (1..12).map { |n| "Page #{n}" })

    expect(response.parsed_body['results'].size).to eq(10)
  end

  it 'refuses a non-editor and an anonymous request' do
    post '/api/v1/characters/batch_preview', params: { wiki_pages: ['Lyria'] },
                                             headers: bearer_headers(create(:user)), as: :json
    expect(response).to have_http_status(:unauthorized)

    post '/api/v1/characters/batch_preview', params: { wiki_pages: ['Lyria'] }, as: :json
    expect(response).to have_http_status(:unauthorized)
    expect(Granblue::Parsers::Wiki).not_to have_received(:new)
  end

  it 'refuses an empty page list' do
    preview('characters', [])

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body).to eq('error' => 'wiki_pages must be a non-empty array')
  end
end
