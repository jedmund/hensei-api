# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ExtensionAuthCode do
  let(:user) { create(:user) }
  let(:verifier) { SecureRandom.urlsafe_base64(32) }
  let(:challenge) { described_class.challenge_for(verifier) }

  describe '.issue' do
    it 'stores only a digest of the code' do
      code = described_class.issue(user, code_challenge: challenge)
      record = described_class.sole

      expect(code).to match(/\A[A-Za-z0-9_-]{43}\z/)
      expect(record.code_digest).to eq(Digest::SHA256.hexdigest(code))
      expect(record.attributes.values.map(&:to_s)).not_to include(code)
      expect(record.expires_at).to be_within(2.seconds).of(60.seconds.from_now)
      expect(record.used_at).to be_nil
    end
  end

  describe '.valid_challenge?' do
    it 'accepts a 43-character base64url S256 challenge' do
      expect(described_class.valid_challenge?(challenge, 'S256')).to be(true)
    end

    it 'rejects other methods and malformed challenges' do
      expect(described_class.valid_challenge?(challenge, 'plain')).to be(false)
      expect(described_class.valid_challenge?(challenge, nil)).to be(false)
      expect(described_class.valid_challenge?("#{challenge}=", 'S256')).to be(false)
      expect(described_class.valid_challenge?(challenge[0, 42], 'S256')).to be(false)
      expect(described_class.valid_challenge?("#{challenge[0, 42]}+", 'S256')).to be(false)
      expect(described_class.valid_challenge?(nil, 'S256')).to be(false)
      expect(described_class.valid_challenge?([challenge], 'S256')).to be(false)
    end
  end

  describe '.redeem' do
    let!(:code) { described_class.issue(user, code_challenge: challenge) }

    it "returns the code's user once" do
      expect(described_class.redeem(code, verifier)).to eq(user)
      expect(described_class.redeem(code, verifier)).to be_nil
    end

    it 'returns nil for an unknown code' do
      expect(described_class.redeem(SecureRandom.urlsafe_base64(32), verifier)).to be_nil
    end

    it 'returns nil for an expired code' do
      travel(61.seconds) { expect(described_class.redeem(code, verifier)).to be_nil }
    end

    it 'returns nil for a wrong verifier, and uses the code up' do
      expect(described_class.redeem(code, SecureRandom.urlsafe_base64(32))).to be_nil
      expect(described_class.redeem(code, verifier)).to be_nil
    end

    it 'returns nil for malformed input' do
      expect(described_class.redeem(nil, verifier)).to be_nil
      expect(described_class.redeem(code, nil)).to be_nil
      expect(described_class.redeem(code, 'short')).to be_nil
      expect(described_class.redeem({ 'a' => 'b' }, verifier)).to be_nil
    end
  end

  describe '#claim!' do
    it 'lets only one of two concurrent redemptions through' do
      # Two requests that both loaded the row before either claimed it.
      first = described_class.find_by(code_digest: described_class.digest(described_class.issue(user, code_challenge: challenge)))
      second = described_class.find(first.id)

      expect([first.claim!, second.claim!]).to contain_exactly(true, false)
    end
  end

  describe '.expired' do
    it 'finds codes past their expiry' do
      described_class.issue(user, code_challenge: challenge)
      expect(described_class.expired).to be_empty
      travel(61.seconds) { expect(described_class.expired.count).to eq(1) }
    end
  end

  it "is deleted with its user" do
    described_class.issue(user, code_challenge: challenge)
    expect { user.destroy! }.to change(described_class, :count).by(-1)
  end
end
