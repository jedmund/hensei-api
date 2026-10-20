# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ExpiresHomeFeed do
  around do |example|
    original = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    example.run
  ensure
    Rails.cache = original
  end

  def cached?
    Rails.cache.exist?(HomeFeed::CACHE_KEY)
  end

  def warm
    Rails.cache.write(HomeFeed::CACHE_KEY, { current: [] })
  end

  it 'clears the cached Home feed when an event changes' do
    event = create(:event, status: :draft)
    warm
    event.update!(status: :approved)
    expect(cached?).to be(false)
  end

  it 'clears it when an event gains or loses a raid' do
    event = create(:event)
    warm
    link = create(:event_raid, event: event, raid: create(:raid))
    expect(cached?).to be(false)

    warm
    link.destroy!
    expect(cached?).to be(false)
  end

  it 'clears it when a staff pick is added' do
    warm
    create(:featured_party, party: create(:party, visibility: 1))
    expect(cached?).to be(false)
  end
end
