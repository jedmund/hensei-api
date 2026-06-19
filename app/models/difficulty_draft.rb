# frozen_string_literal: true

##
# A single pending change made by an editor against the canonical difficulty
# ruleset. Drafts are applied via PartyDifficulty::DraftWorkspace and either
# promoted to canonical via commit, or discarded.
class DifficultyDraft < ApplicationRecord
  TARGET_TYPES = %w[Difficulty DifficultyRule DifficultyComponent].freeze
  OPERATIONS = %w[create update destroy].freeze

  belongs_to :user

  validates :target_type, inclusion: { in: TARGET_TYPES }
  validates :operation, inclusion: { in: OPERATIONS }
  validate :target_id_present_for_update_or_destroy

  scope :for_user, ->(user) { where(user_id: user.id) }
  scope :of_type, ->(type) { where(target_type: type.to_s) }

  def attributes_payload
    self[:attributes_payload] || {}
  end

  def target_class
    target_type.constantize
  end

  def target
    return nil if target_id.blank?

    target_class.find_by(id: target_id)
  end

  private

  def target_id_present_for_update_or_destroy
    return if operation == 'create'
    return if target_id.present?

    errors.add(:target_id, "is required for #{operation}")
  end
end
