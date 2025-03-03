# frozen_string_literal.rb

class SummonAura < ApplicationRecord
  belongs_to :summon, primary_key: 'granblue_id', foreign_key: 'summon_granblue_id', optional: true

  validates :summon_granblue_id, presence: true
  validates :aura_type, presence: true
  validates :aura_type, uniqueness: { scope: %i[summon_granblue_id uncap_level] }

  enum aura_type: { main: 1, sub: 2 }
  enum boost_type: { weapon_skill: 1, elemental: 2, stat: 3 }

  scope :by_uncap_level, ->(level) { where(uncap_level: level) }
end
