# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Sources::FetchWikiStatusListJob do
  it 'fetches the status list' do
    source = Source.new(sha256: 'abcdef1234567890')
    allow(Sources::WikiStatusList).to receive(:fetch!).and_return(Sources::WikiStatusList::Result.new(source: source, changed: true))
    described_class.perform_now
    expect(Sources::WikiStatusList).to have_received(:fetch!)
  end

  it "discards a page that doesn't validate (retrying won't help; the stored list stays)" do
    allow(Sources::WikiStatusList).to receive(:fetch!).and_raise(Granblue::Parsers::StatusList::Invalid, 'no buffs or debuffs')
    expect { described_class.perform_now }.not_to raise_error
  end
end
