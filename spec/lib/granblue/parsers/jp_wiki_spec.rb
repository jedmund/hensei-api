# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Granblue::Parsers::JpWiki do
  let(:client) { described_class.new }

  before do
    allow(Rails.application.credentials).to receive(:wiki_user_agent).and_return('TestBot/1.0')
  end

  it 'returns the page body' do
    stub_request(:get, %r{\Ahttps://gbf-wiki\.com/}).to_return(status: 200, body: '<html>ok</html>')
    expect(client.fetch('ヴィーラ')).to eq('<html>ok</html>')
  end

  it 'raises a 504 WikiError when the wiki does not answer in time' do
    stub_request(:get, %r{\Ahttps://gbf-wiki\.com/}).to_timeout
    expect { client.fetch('ヴィーラ') }.to raise_error(Granblue::WikiError) { |e|
      expect(e.code).to eq(504)
      expect(e.page).to eq('ヴィーラ')
    }
  end
end
