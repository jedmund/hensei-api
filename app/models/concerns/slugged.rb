# frozen_string_literal: true

# A record named by a slug: lowercase words joined by hyphens (dark-opus,
# weapon-atk). Slugs appear in URLs and name image files, so they stay
# path-safe and unique.
module Slugged
  extend ActiveSupport::Concern

  FORMAT = /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/

  included do
    validates :slug, presence: true, uniqueness: true, format: { with: FORMAT }, length: { maximum: 64 }
  end
end
