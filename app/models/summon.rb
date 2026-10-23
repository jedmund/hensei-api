# frozen_string_literal: true

class Summon < ApplicationRecord
  include PgSearch::Model
  include HasSources

  # The fetched sources live in `sources` (D35, PR 7b).
  source_attribute :wiki_raw, fetched_at: :wiki_raw_fetched_at
  # Only div#body of the gbf-wiki.com page (Granblue::JpWikiPage.trim, done by the fetch).
  source_attribute :wiki_raw_jp, fetched_at: :wiki_raw_jp_fetched_at
  # Stored game payloads keep only the item's data, whoever writes them (import, Dataminer).
  source_attribute :game_raw_en, fetched_at: :game_raw_en_fetched_at, filter: Granblue::GamePayload.method(:sanitize_item)
  source_attribute :game_raw_jp, fetched_at: :game_raw_jp_fetched_at, filter: Granblue::GamePayload.method(:sanitize_item)

  # Stored in MediaWiki's canonical form (Granblue::WikiTitle); links encode it.
  normalizes :wiki_en, with: ->(title) { Granblue::WikiTitle.normalize(title) }
  # A plain gbf-wiki.com title (Granblue::JpWikiTitle): a pasted percent-encoded one is decoded.
  normalizes :wiki_ja, with: ->(title) { Granblue::JpWikiTitle.normalize(title) }

  belongs_to :summon_series, optional: true
  has_many :auras, class_name: "SummonAura", foreign_key: :summon_granblue_id,
                   primary_key: :granblue_id, inverse_of: :summon, dependent: :destroy

  # Aura build: a new summon, or a change to anything its auras are built from
  # (SummonAuras::Build::Fingerprint: its wiki_raw and ATTRIBUTES), queues
  # SummonAuras::BuildJob. Covers every writer: a save of the summon, or a Source.put for it
  # (.source_changed). Bulk work can skip it with Summon.without_aura_build { ... }; the
  # deploy build picks those summons up.
  thread_cattr_accessor :skip_aura_build, instance_accessor: false
  after_save :capture_aura_build
  after_commit :enqueue_aura_build, on: %i[create update], if: :aura_inputs_changed?

  def self.without_aura_build
    previous = skip_aura_build
    self.skip_aura_build = true
    yield
  ensure
    self.skip_aura_build = previous
  end

  # Source hooks: a source written outside a save of the summon (Source.put).
  def self.source_change_hook?(kind)
    !skip_aura_build && SummonAuras::Build::Fingerprint::SOURCES.include?(kind)
  end

  def self.source_changed(summon_id, _kind)
    granblue_id = where(id: summon_id).pick(:granblue_id)
    return unless granblue_id
    return unless Source.exists?(owner_type: polymorphic_name, owner_id: summon_id, kind: "wiki_raw") ||
                  SummonAura.exists?(summon_granblue_id: granblue_id)

    SummonAuras::BuildJob.perform_later(summon_id)
  end

  multisearchable against: %i[name_en name_jp],
                  additional_attributes: lambda { |summon|
                    {
                      name_en: summon.name_en,
                      name_jp: summon.name_jp,
                      granblue_id: summon.granblue_id,
                      element: summon.element
                    }
                  }

  pg_search_scope :en_search,
                  against: %i[name_en nicknames_en],
                  using: {
                    tsearch: {
                      prefix: true,
                      dictionary: 'simple'
                    },
                    trigram: {
                      threshold: 0.18
                    }
                  }

  pg_search_scope :ja_search,
                  against: %i[name_jp nicknames_jp],
                  using: {
                    tsearch: {
                      prefix: true,
                      dictionary: 'simple'
                    }
                  }

  def blueprint
    SummonBlueprint
  end

  def display_resource(summon)
    summon.name_en
  end

  # Promotion scopes
  scope :by_promotion, ->(promotion) { where('? = ANY(promotions)', promotion) }
  scope :in_premium, -> { by_promotion(GranblueEnums::PROMOTIONS[:Premium]) }
  scope :in_classic, -> { by_promotion(GranblueEnums::PROMOTIONS[:Classic]) }
  scope :flash_exclusive, -> { by_promotion(GranblueEnums::PROMOTIONS[:Flash]).where.not('? = ANY(promotions)', GranblueEnums::PROMOTIONS[:Legend]) }
  scope :legend_exclusive, -> { by_promotion(GranblueEnums::PROMOTIONS[:Legend]).where.not('? = ANY(promotions)', GranblueEnums::PROMOTIONS[:Flash]) }

  # Promotion helpers
  def flash?
    promotions.include?(GranblueEnums::PROMOTIONS[:Flash])
  end

  def legend?
    promotions.include?(GranblueEnums::PROMOTIONS[:Legend])
  end

  def premium?
    promotions.include?(GranblueEnums::PROMOTIONS[:Premium])
  end

  def promotion_names
    promotions.filter_map { |p| GranblueEnums::PROMOTIONS.key(p)&.to_s }
  end

  def series_slug
    summon_series&.slug
  end

  # Virtual attribute to set summon_series by ID or slug
  # Supports both UUID and slug lookup for flexibility
  def series=(value)
    return self.summon_series = nil if value.blank?

    # Try to find by ID first, then by slug
    found = SummonSeries.find_by(id: value) || SummonSeries.find_by(slug: value)
    self.summon_series = found
  end

  private

  def capture_aura_build
    fingerprint = SummonAuras::Build::Fingerprint
    @aura_build_pending = !self.class.skip_aura_build &&
                          (saved_changes.keys.intersect?(fingerprint::ATTRIBUTES) ||
                           saved_source_changes.intersect?(fingerprint::SOURCES))
  end

  def aura_inputs_changed?
    return false unless @aura_build_pending

    @aura_build_pending = false
    # Nothing to build from and nothing to keep: the job would be a no-op.
    source_sha256(:wiki_raw).present? || SummonAura.exists?(summon_granblue_id: granblue_id)
  end

  def enqueue_aura_build
    SummonAuras::BuildJob.perform_later(id)
  end
end
