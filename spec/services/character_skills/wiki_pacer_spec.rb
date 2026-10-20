# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CharacterSkills::WikiPacer do
  let(:now) { [100.0] }
  let(:sleeps) { [] }
  let(:pacer) do
    described_class.new(clock: -> { now.first }, sleeper: lambda { |seconds|
                          sleeps << seconds
                          now[0] += seconds
                        })
  end

  it "doesn't wait for a site's first request" do
    pacer.wait(:gbf_wiki)
    expect(sleeps).to be_empty
  end

  it 'waits out the rest of the minimum delay between requests to one site' do
    pacer.wait(:gbf_wiki)
    now[0] += 0.5
    pacer.wait(:gbf_wiki)
    expect(sleeps).to eq([Granblue::WikiThrottle::MIN_DELAY - 0.5])
  end

  it "doesn't wait once the delay has passed" do
    pacer.wait(:gbf_wiki)
    now[0] += 2.5
    pacer.wait(:gbf_wiki)
    expect(sleeps).to be_empty
  end

  it 'paces each site on its own' do
    pacer.wait(:gbf_wiki)
    pacer.wait(:gbf_wiki_jp)
    expect(sleeps).to be_empty
  end

  it 'hands the fetchers a hook for one site' do
    hook = pacer.before_request(:gbf_wiki_jp)
    hook.call
    hook.call
    expect(sleeps).to eq([Granblue::WikiThrottle::MIN_DELAY])
  end

  it 'refuses an unknown site' do
    expect { pacer.wait(:elsewhere) }.to raise_error(ArgumentError)
  end
end
