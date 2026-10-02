# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SocialAuth::UsernameSuggester do
  it 'strips characters usernames cannot contain' do
    expect(described_class.call('nelly.dev')).to eq('nellydev')
  end

  it 'adds digits when the username is taken' do
    create(:user, username: 'nellydev')
    expect(described_class.call('nelly.dev')).to match(/\Anellydev\d{4}\z/)
  end

  it 'returns nil when too little is left' do
    expect(described_class.call('日本語')).to be_nil
    expect(described_class.call(nil)).to be_nil
  end

  it 'keeps suggestions within the length limit' do
    expect(described_class.call('a' * 40).length).to eq(26)
  end
end
