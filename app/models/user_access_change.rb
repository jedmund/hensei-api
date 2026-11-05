# frozen_string_literal: true

##
# Append-only log of changes to a user's access made by admins (see
# Api::V1::Admin::UsersController). Never updated or deleted by the app.
# Both users are optional once saved: either account may be deleted later,
# which clears the link. New records need both.
class UserAccessChange < ApplicationRecord
  KINDS = %w[role].freeze

  belongs_to :user, optional: true
  belongs_to :actor, class_name: 'User', optional: true

  validates :user, :actor, presence: true, on: :create
  validates :kind, inclusion: { in: KINDS }
  validates :from_role, :to_role, presence: true, if: -> { kind == 'role' }

  scope :recent_first, -> { order(created_at: :desc) }
end
