# frozen_string_literal: true

class SkillEffect < ApplicationRecord
  belongs_to :skill
  belongs_to :effect

  validates :target_type, presence: true
  validates :duration_type, presence: true

  enum target_type: { self: 1, ally: 2, all_allies: 3, enemy: 4, all_enemies: 5 }
  enum duration_type: { turns: 1, seconds: 2, indefinite: 3, one_time: 4 }

  scope :local, -> { where(local: true) }
  scope :global, -> { where(local: false) }
  scope :permanent, -> { where(permanent: true) }
  scope :undispellable, -> { where(undispellable: true) }
end
