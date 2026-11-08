# frozen_string_literal: true

require 'rails_helper'

# Sentry HENSEI-API-16: skill_boosts looked up summon_auras once per summon, slot
# and frame. The party's rows now load in one query.
RSpec.describe GridDamage::SummonAuras do
  def summon_aura_queries
    queries = []
    sub = ActiveSupport::Notifications.subscribe('sql.active_record') do |*, payload|
      queries << payload[:sql] if payload[:sql].include?('FROM "summon_auras"')
    end
    yield
    queries
  ensure
    ActiveSupport::Notifications.unsubscribe(sub)
  end

  it "loads a party's summon auras in one query" do
    party = Granblue::GoldenFixture.load('XZq7xW', mode: :replace)
    expect(party.summons.count).to be > 1

    queries = summon_aura_queries { described_class.for_party(party, element: 'water') }

    expect(queries.size).to eq(1)
  end
end
