# frozen_string_literal: true

# Something that happened to a user: a sticker or remix on their team, a
# staff feature, a crew invitation or a phantom assignment (GBF-82). Written
# by Notifications::Publisher; read through NotificationsController.
#
# Invitations and phantom assignments are actionable: their state (pending,
# accepted, ...) is read from the subject, so lazily expiring invitations
# resolve without a write here.
class Notification < ApplicationRecord
  enum :kind, {
    sticker_received: 0,
    party_remixed: 1,
    party_featured: 2,
    crew_invited: 3,
    phantom_assigned: 4
  }

  ACTIONABLE_KINDS = %w[crew_invited phantom_assigned].freeze

  belongs_to :recipient, class_name: 'User'
  belongs_to :actor, class_name: 'User', optional: true
  belongs_to :subject, polymorphic: true

  validates :count, numericality: { only_integer: true, greater_than: 0 }
  # Givers stay anonymous
  validates :actor_id, absence: true, if: :sticker_received?

  scope :unread, -> { where(read_at: nil) }
  scope :newest_first, -> { order(updated_at: :desc, id: :desc) }
  scope :passive, -> { where.not(kind: ACTIONABLE_KINDS) }

  # What the jewel's badge shows: passive rows that changed since the user
  # last opened it, plus every actionable row still waiting on them.
  def self.unread_count_for(user)
    passive = where(recipient: user).passive.unread
    passive = passive.where('notifications.updated_at > ?', user.notifications_seen_at) if user.notifications_seen_at

    passive.count + pending_for(user).count
  end

  # Actionable rows still waiting on their recipient, across all users:
  # active invitations to them, and phantoms still claimed by them and not
  # yet confirmed. Rows whose subject is gone never match.
  scope :pending, lambda {
    invitations = CrewInvitation.active.where('crew_invitations.id = notifications.subject_id')
                                .where('crew_invitations.user_id = notifications.recipient_id')
    phantoms = PhantomPlayer.not_deleted.where(claim_confirmed: false)
                            .where('phantom_players.id = notifications.subject_id')
                            .where('phantom_players.claimed_by_id = notifications.recipient_id')

    pending_invitations = where(kind: :crew_invited, subject_type: 'CrewInvitation').where(invitations.arel.exists)
    pending_phantoms = where(kind: :phantom_assigned, subject_type: 'PhantomPlayer').where(phantoms.arel.exists)

    pending_invitations.or(pending_phantoms)
  }
  # Actionable rows that no longer need anything: accepted, declined,
  # expired, reassigned, or whose subject was deleted.
  scope :resolved, -> { where(kind: ACTIONABLE_KINDS).where.not(id: pending.select(:id)) }

  def self.pending_for(user)
    where(recipient: user).pending
  end

  def actionable?
    ACTIONABLE_KINDS.include?(kind)
  end

  # nil for passive kinds. Invitations: pending, accepted, rejected or
  # expired. Phantoms: pending, confirmed, or unassigned (declined, or given
  # to someone else).
  def state
    case kind
    when 'crew_invited' then invitation_state
    when 'phantom_assigned' then phantom_state
    end
  end

  private

  def invitation_state
    return 'expired' if subject.pending? && !subject.active?

    subject.status
  end

  def phantom_state
    return 'unassigned' unless subject.claimed_by_id == recipient_id
    return 'confirmed' if subject.claim_confirmed?

    subject.deleted_at.nil? ? 'pending' : 'unassigned'
  end
end
