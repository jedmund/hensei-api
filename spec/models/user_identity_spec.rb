# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UserIdentity do
  let(:user) { create(:user) }

  it 'links a provider account to a user' do
    identity = user.user_identities.create!(provider: 'google', provider_uid: 'sub-1')
    expect(identity.as_api_json).to include(provider: 'google', email: nil, is_private_email: false)
  end

  it 'rejects unknown providers' do
    expect(user.user_identities.build(provider: 'myspace', provider_uid: '1')).not_to be_valid
  end

  it 'allows each provider account to be linked to only one user' do
    user.user_identities.create!(provider: 'discord', provider_uid: '1')
    duplicate = create(:user).user_identities.build(provider: 'discord', provider_uid: '1')

    expect(duplicate).not_to be_valid
    expect { duplicate.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
  end

  it 'allows one identity per provider per user' do
    user.user_identities.create!(provider: 'discord', provider_uid: '1')
    second = user.user_identities.build(provider: 'discord', provider_uid: '2')

    expect(second).not_to be_valid
    expect { second.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
  end

  it 'is destroyed with its user' do
    user.user_identities.create!(provider: 'apple', provider_uid: 'x')
    expect { user.destroy }.to change(described_class, :count).by(-1)
  end
end
