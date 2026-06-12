# frozen_string_literal: true

class CharacterSkillVersionLink < ApplicationRecord
  belongs_to :from_version, class_name: 'CharacterSkillVersion', inverse_of: :outgoing_links
  belongs_to :to_version, class_name: 'CharacterSkillVersion', inverse_of: :incoming_links

  enum :relation, { transforms_to: 'transforms_to', option_of: 'option_of', form_counterpart: 'form_counterpart' }

  validates :relation, presence: true
  validates :from_version_id, uniqueness: { scope: %i[to_version_id relation] }
end
