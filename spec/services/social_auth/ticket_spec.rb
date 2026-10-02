# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SocialAuth::Ticket do
  let(:identity) do
    SocialAuth::Identity.new(provider: 'discord', uid: '42', email: 'a@example.com', is_private_email: false, name: nil)
  end

  it 'round-trips the identity for the same purpose' do
    ticket = described_class.issue(identity, purpose: :signup)
    payload = described_class.read(ticket, purpose: :signup)

    expect(payload).to include('provider' => 'discord', 'provider_uid' => '42', 'email' => 'a@example.com',
                               'email_verified' => true, 'is_private_email' => false)
    expect(described_class.issued_at(payload)).to be_within(1.second).of(Time.current)
  end

  it 'rejects a ticket for the other purpose' do
    ticket = described_class.issue(identity, purpose: :signup)
    expect(described_class.read(ticket, purpose: :link)).to be_nil
  end

  it 'expires after 10 minutes' do
    ticket = described_class.issue(identity, purpose: :link)

    travel 9.minutes
    expect(described_class.read(ticket, purpose: :link)).to be_present
    travel 2.minutes
    expect(described_class.read(ticket, purpose: :link)).to be_nil
  end

  it 'rejects a tampered ticket' do
    ticket = described_class.issue(identity, purpose: :signup)
    data, digest = ticket.split('--')
    forged = data.dup
    forged[20] = forged[20] == 'A' ? 'B' : 'A'

    expect(forged).not_to eq(data)
    expect(described_class.read("#{forged}--#{digest}", purpose: :signup)).to be_nil
    expect(described_class.read("#{data}--#{digest.reverse}", purpose: :signup)).to be_nil
  end

  it 'rejects blank and non-string tickets' do
    expect(described_class.read(nil, purpose: :signup)).to be_nil
    expect(described_class.read('', purpose: :signup)).to be_nil
    expect(described_class.read({ 'a' => 1 }, purpose: :signup)).to be_nil
  end

  it 'refuses unknown purposes' do
    expect { described_class.issue(identity, purpose: :admin) }.to raise_error(ArgumentError)
  end
end
