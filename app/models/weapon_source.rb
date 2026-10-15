# frozen_string_literal: true

# One stored gbf.wiki input for the weapon-skill build (see WeaponSkills::SourceStore).
# weapon_id is null for pages no single weapon owns: family templates and key series pages.
class WeaponSource < ApplicationRecord
  belongs_to :weapon, optional: true

  validates :kind, inclusion: { in: WeaponSkills::SourceStore::KINDS }
  validates :page_kind, inclusion: { in: WeaponSkills::SourceStore::PAGE_KINDS }, allow_nil: true
  validates :key, presence: true
  validates :body, :sha256, :fetched_at, presence: true

  before_validation { self.sha256 = Digest::SHA256.hexdigest(body.to_s) if body }

  def to_source
    WeaponSkills::SourceStore::Source.new(kind: kind, key: key, body: body, sha256: sha256,
                                          fetched_at: fetched_at, page_kind: page_kind)
  end
end
