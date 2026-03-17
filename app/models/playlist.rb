# frozen_string_literal: true

class Playlist < ApplicationRecord
  belongs_to :user
  has_many :playlist_parties, dependent: :destroy
  has_many :parties, through: :playlist_parties

  before_validation :generate_slug, if: -> { title.present? && (new_record? || title_changed?) }

  validates :title, presence: true, uniqueness: { scope: :user_id }
  validates :slug, presence: true, uniqueness: { scope: :user_id }
  validates :visibility,
            numericality: { only_integer: true },
            inclusion: {
              in: [1, 2, 3],
              message: 'must be 1 (Public), 2 (Unlisted), or 3 (Private)'
            }

  YOUTUBE_REGEX = %r{\A(?:https?://)?(?:www\.)?(?:youtube\.com/watch\?v=|youtu\.be/)[\w-]+}
  validates :video_url, format: { with: YOUTUBE_REGEX, message: 'must be a valid YouTube URL' }, allow_blank: true

  scope :visible_to, ->(viewer, owner) {
    if viewer && viewer == owner
      all
    else
      where(visibility: [1, 2])
    end
  }

  def public?
    visibility == 1
  end

  def unlisted?
    visibility == 2
  end

  def private?
    visibility == 3
  end

  def owned_by?(user)
    user.present? && user_id == user.id
  end

  def viewable_by?(viewer)
    return true if public? || unlisted?
    return true if owned_by?(viewer)

    false
  end

  private

  def generate_slug
    base = title.parameterize.presence || SecureRandom.alphanumeric(8).downcase
    candidate = base
    counter = 1

    while user && Playlist.where(user_id: user_id, slug: candidate).where.not(id: id).exists?
      counter += 1
      candidate = "#{base}-#{counter}"
    end

    self.slug = candidate
  end
end
