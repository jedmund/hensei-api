# frozen_string_literal: true

class SummonCall < ApplicationRecord
  belongs_to :skill
  belongs_to :alt_skill, class_name: 'Skill', optional: true
  belongs_to :summon, primary_key: 'granblue_id', foreign_key: 'summon_granblue_id', optional: true

  validates :summon_granblue_id, presence: true
  validates :uncap_level, uniqueness: { scope: :summon_granblue_id }

  scope :by_uncap_level, ->(level) { where(uncap_level: level) }
end
