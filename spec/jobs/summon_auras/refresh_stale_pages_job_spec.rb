# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SummonAuras::RefreshStalePagesJob do
  it 'refreshes a capped batch of stale summon pages' do
    allow(SummonAuras::StalePages).to receive(:refresh).and_return([[], []])
    described_class.perform_now
    expect(SummonAuras::StalePages).to have_received(:refresh).with(limit: described_class::LIMIT, io: kind_of(StringIO))
  end
end
