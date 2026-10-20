# frozen_string_literal: true

require 'rails_helper'

# The legacy per-model wiki fetch loops wait 2 seconds between pages.
RSpec.describe 'Legacy wiki fetch loops' do
  {
    Granblue::Parsers::CharacterParser => :character,
    Granblue::Parsers::WeaponParser => :weapon,
    Granblue::Parsers::SummonParser => :summon
  }.each do |parser, factory|
    describe "#{parser}.fetch_list" do
      it 'sleeps 2 seconds after each fetch' do
        record = create(factory, release_date: nil)
        fetcher = instance_double(parser, fetch: nil)
        # CharacterParser.fetch_list builds a WeaponParser (an old bug, left as is).
        allow(Granblue::Parsers::WeaponParser).to receive(:new).and_return(fetcher) if parser == Granblue::Parsers::CharacterParser
        allow(parser).to receive(:new).and_return(fetcher)
        allow(parser).to receive(:sleep)
        allow(parser).to receive(:ap)
        allow(fetcher).to receive(:fetch)

        parser.fetch_list(list: [record.granblue_id])

        expect(parser).to have_received(:sleep).with(2.0).once
      end
    end
  end
end
