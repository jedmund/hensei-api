# frozen_string_literal: true

# One stored gbf.wiki input for the weapon-skill build (see WeaponSkills::SourceStore): the
# store's rows of the shared `sources` table (D34, PR 7b), keyed by page title. owner_id is
# the weapon (weapon_id here); it's null for pages no single weapon owns: family templates
# and key series pages.
#
# The store's rows are the weapon-skill kinds with a title for a key, owned by a weapon or by
# nothing. A weapon's own wiki_raw attribute (key '', Weapon#wiki_raw) and other owners' rows
# aren't part of it.
class WeaponSource < ApplicationRecord
  self.table_name = 'sources'

  default_scope do
    where(kind: WeaponSkills::SourceStore::KINDS, owner_type: [nil, Weapon.polymorphic_name]).where.not(key: '')
  end

  alias_attribute :weapon_id, :owner_id
  belongs_to :weapon, foreign_key: :owner_id, optional: true, inverse_of: false

  validates :kind, inclusion: { in: WeaponSkills::SourceStore::KINDS }
  validates :page_kind, inclusion: { in: WeaponSkills::SourceStore::PAGE_KINDS }, allow_nil: true
  validates :key, presence: true
  validates :body, :sha256, :fetched_at, presence: true

  before_validation do
    self.owner_type = owner_id ? Weapon.polymorphic_name : nil
    self.sha256 = Digest::SHA256.hexdigest(body.to_s) if body
  end

  def to_source
    WeaponSkills::SourceStore::Source.new(kind: kind, key: key, body: body, sha256: sha256,
                                          fetched_at: fetched_at, page_kind: page_kind)
  end
end
