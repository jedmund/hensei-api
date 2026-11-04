# frozen_string_literal: true

require 'rails_helper'

# POST /characters/:id/download_image: which variant is fetched for each
# combination of transformation, element and gender, and what's refused.
RSpec.describe 'Character image download', type: :request do
  include CommunitySpecHelpers

  let(:editor) { create(:user, role: 7) }
  let(:character) { create(:character, granblue_id: '3040001000') }
  let(:url) { "/api/v1/characters/#{character.id}/download_image" }
  let(:downloader) { double('CharacterDownloader') } # rubocop:disable RSpec/VerifiedDoubles
  let(:downloader_class) { Granblue::Downloaders::CharacterDownloader }

  before do
    allow(downloader_class).to receive(:new).and_return(downloader)
    allow(downloader).to receive(:download_variant)
    allow(downloader).to receive(:download_style_variant)
  end

  def download(**params)
    post url, params: { size: 'grid', **params }, headers: bearer_headers(editor), as: :json
  end

  it 'downloads the base pose and describes it' do
    download(force: true)

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to eq(
      'success' => true, 'character_id' => character.id, 'granblue_id' => '3040001000', 'size' => 'grid',
      'transformation' => nil, 'element' => nil, 'message' => 'Image downloaded successfully'
    )
    expect(downloader_class).to have_received(:new).with('3040001000', storage: :s3, force: true, verbose: true)
    expect(downloader).to have_received(:download_variant).with('3040001000_01', 'grid')
  end

  it 'adds the pose, element and gender suffixes' do
    download(transformation: '03', element: 4, gender: 1)

    expect(response.parsed_body).to include('transformation' => '03', 'element' => 4)
    expect(downloader).to have_received(:download_variant).with('3040001000_03_04_1', 'grid')
  end

  it 'adds a gender suffix of 0 only when gender is given' do
    download(gender: 0)

    expect(downloader).to have_received(:download_variant).with('3040001000_01_0', 'grid')
  end

  it 'downloads the style variant when asked' do
    download(transformation: 'style')

    expect(downloader).to have_received(:download_style_variant).with('grid')
    expect(downloader).not_to have_received(:download_variant)
  end

  it 'downloads the style variant by default for a style swap' do
    character.update!(style_swap: true)

    download

    expect(downloader).to have_received(:download_style_variant).with('grid')
  end

  it 'uses the given pose for a style swap' do
    character.update!(style_swap: true)

    download(transformation: '02')

    expect(downloader).to have_received(:download_variant).with('3040001000_02', 'grid')
  end

  it 'refuses an unknown transformation' do
    download(transformation: '05')

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body).to eq('error' => 'Invalid transformation. Must be one of: 01, 02, 03, 04, style')
  end

  it 'refuses an element outside 1-6, including 0' do
    [0, 7].each do |element|
      download(element: element)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body).to eq('error' => 'Invalid element. Must be 1-6')
    end
  end

  it 'refuses a gender other than 0 or 1' do
    download(gender: 2)

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body).to eq('error' => 'Invalid gender. Must be 0 (Gran) or 1 (Djeeta)')
  end

  it 'refuses an unknown size' do
    download(size: 'huge')

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body['error']).to start_with('Invalid size')
  end

  it 'reports a download failure as a 500 with the message' do
    allow(downloader).to receive(:download_variant).and_raise(StandardError, 'boom')

    download

    expect(response).to have_http_status(:internal_server_error)
    expect(response.parsed_body).to eq('success' => false, 'error' => 'boom')
  end

  it 'refuses a non-editor' do
    post url, params: { size: 'grid' }, headers: bearer_headers(create(:user)), as: :json

    expect(response).to have_http_status(:unauthorized)
    expect(downloader_class).not_to have_received(:new)
  end

  it 'refuses an anonymous request' do
    post url, params: { size: 'grid' }, as: :json

    expect(response).to have_http_status(:unauthorized)
  end
end
