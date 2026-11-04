# frozen_string_literal: true

class Weapon < ApplicationRecord
  include PgSearch::Model
  include HasSources
  include UncapTiers

  # The fetched sources live in `sources` (D35, PR 7b).
  # The weapon's page is one row, keyed by its page title (wiki_en): the weapon-skill source
  # store (WeaponSource) and the build read it by title. A page stored without the store's
  # fetch (an editor's wiki import) is titled too; only a weapon with no wiki_en keeps key ''.
  source_attribute :wiki_raw, fetched_at: :wiki_raw_fetched_at, titled: :wiki_en
  # Only div#body of the gbf-wiki.com page (Granblue::JpWikiPage.trim, done by the fetch).
  source_attribute :wiki_raw_jp, fetched_at: :wiki_raw_jp_fetched_at
  # Stored game payloads keep only the item's data, whoever writes them (import, Dataminer).
  source_attribute :game_raw_en, fetched_at: :game_raw_en_fetched_at, filter: Granblue::GamePayload.method(:sanitize_item)
  source_attribute :game_raw_jp, fetched_at: :game_raw_jp_fetched_at, filter: Granblue::GamePayload.method(:sanitize_item)

  # Skill build: a new page, or a change to the page or its title, queues WeaponSkills::BuildJob
  # once the save commits. Every writer of a weapon's page saves the weapon (editor import, wiki
  # fetch, SourceStore::Fetcher). Bulk work skips it with Weapon.without_skill_build { ... }; the
  # deploy build picks those weapons up.
  thread_cattr_accessor :skip_skill_build, instance_accessor: false
  after_save :capture_skill_build
  after_commit :enqueue_skill_build, on: %i[create update], if: :skill_inputs_changed?

  def self.without_skill_build
    previous = skip_skill_build
    self.skip_skill_build = true
    yield
  ensure
    self.skip_skill_build = previous
  end

  # Stored in MediaWiki's canonical form (Granblue::WikiTitle); links encode it.
  normalizes :wiki_en, with: ->(title) { Granblue::WikiTitle.normalize(title) }
  # A plain gbf-wiki.com title (Granblue::JpWikiTitle): a pasted percent-encoded one is decoded.
  normalizes :wiki_ja, with: ->(title) { Granblue::JpWikiTitle.normalize(title) }

  multisearchable against: %i[name_en name_jp],
                  additional_attributes: lambda { |weapon|
                    {
                      name_en: weapon.name_en,
                      name_jp: weapon.name_jp,
                      granblue_id: weapon.granblue_id,
                      element: weapon.element
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

  # Pure join rows (which awakenings the weapon can take): they go with it.
  has_many :weapon_awakenings, dependent: :destroy
  has_many :awakenings, through: :weapon_awakenings
  # Built and curated skill data: remove it on purpose before deleting the weapon.
  has_many :weapon_skills, -> { order(:position) }, primary_key: :granblue_id, foreign_key: :weapon_granblue_id, inverse_of: :weapon,
                                                    dependent: :restrict_with_error
  has_many :weapon_skill_versions, through: :weapon_skills
  has_many :skills, through: :weapon_skill_versions
  belongs_to :weapon_series, optional: true
  belongs_to :weapon_series_variant, optional: true
  belongs_to :recruited_character, class_name: 'Character', primary_key: :granblue_id, foreign_key: :recruits, optional: true,
                                   inverse_of: false
  belongs_to :base_weapon, class_name: 'Weapon', primary_key: :granblue_id, foreign_key: :forged_from, optional: true,
                           inverse_of: false
  # Every weapon sharing the chain id, this one included, so a restrict would
  # block deleting any chain member; the others are left as they are.
  has_many :forge_chain_weapons, class_name: 'Weapon', primary_key: :forge_chain_id, foreign_key: :forge_chain_id,
                                 inverse_of: false, dependent: nil

  def blueprint
    WeaponBlueprint
  end

  def display_resource(weapon)
    weapon.name_en
  end

  ##
  # The uncap level a weapon starts at when placed in a grid: its max, except
  # that an extra slot (9-11) starts a weapon with an extra prerequisite at
  # that prerequisite.
  #
  # @param position [Integer, String, nil] the slot it's placed in
  # @return [Integer]
  def default_uncap_level(position = nil)
    in_extra_slot = position && GridWeapon::EXTRA_POSITIONS.include?(position.to_i)
    return [extra_prerequisite, max_uncap_level].min if in_extra_slot && extra_prerequisite.present?

    max_uncap_level
  end

  def compatible_with_key?(key)
    return false if weapon_series.blank?
    return false unless effective_has_weapon_keys

    key.weapon_series.include?(weapon_series)
  end

  # Returns whether the weapon is included in the Draconic or Dark Opus series
  def opus_or_draconic?
    return false if weapon_series.blank?

    [WeaponSeries::DARK_OPUS, WeaponSeries::DRACONIC].include?(weapon_series.slug)
  end

  # Returns whether the weapon belongs to the Draconic Weapon series or the Draconic Weapon Providence series
  def draconic_or_providence?
    return false if weapon_series.blank?

    [WeaponSeries::DRACONIC, WeaponSeries::DRACONIC_PROVIDENCE].include?(weapon_series.slug)
  end

  def self.element_changeable?(weapon_or_series)
    if weapon_or_series.is_a?(Weapon)
      weapon_or_series.effective_element_changeable
    elsif weapon_or_series.is_a?(WeaponSeries)
      weapon_or_series.element_changeable
    else
      false
    end
  end

  # Variant-aware capability accessors. Returns the variant override if present,
  # otherwise falls back to the weapon series value.
  def effective_has_weapon_keys
    return weapon_series_variant.has_weapon_keys unless weapon_series_variant&.has_weapon_keys.nil?

    weapon_series&.has_weapon_keys || false
  end

  def effective_has_awakening
    return weapon_series_variant.has_awakening unless weapon_series_variant&.has_awakening.nil?

    weapon_series&.has_awakening || false
  end

  def effective_element_changeable
    return weapon_series_variant.element_changeable unless weapon_series_variant&.element_changeable.nil?

    weapon_series&.element_changeable || false
  end

  def effective_extra
    return weapon_series_variant.extra unless weapon_series_variant&.extra.nil?

    weapon_series&.extra || false
  end

  def effective_num_weapon_keys
    return weapon_series_variant.num_weapon_keys unless weapon_series_variant&.num_weapon_keys.nil?

    weapon_series&.num_weapon_keys
  end

  def effective_augment_type
    return weapon_series_variant.augment_type unless weapon_series_variant&.augment_type.nil?

    weapon_series&.augment_type || 'no_augment'
  end

  # AX slot rules (gbf.wiki/AX_Skills) are defined by series: 'standard'
  # (Omega/Ancestral — per-primary secondary pools), 'xeno' (different pools
  # incl. supplementals), 'primal' (Primal and Ancient weapons — standard pools
  # plus EXP/Rupie primaries, which have no secondary).
  def effective_ax_type
    return unless effective_augment_type == 'ax'

    case weapon_series&.slug
    when 'xeno' then 'xeno'
    when 'primal', 'olden-primal' then 'primal'
    else 'standard'
    end
  end

  # Promotion scopes
  scope :by_promotion, ->(promotion) { where('? = ANY(promotions)', promotion) }
  scope :in_premium, -> { by_promotion(GranblueEnums::PROMOTIONS[:Premium]) }
  scope :in_classic, -> { by_promotion(GranblueEnums::PROMOTIONS[:Classic]) }
  scope :flash_exclusive, -> { by_promotion(GranblueEnums::PROMOTIONS[:Flash]).where.not('? = ANY(promotions)', GranblueEnums::PROMOTIONS[:Legend]) }
  scope :legend_exclusive, -> { by_promotion(GranblueEnums::PROMOTIONS[:Legend]).where.not('? = ANY(promotions)', GranblueEnums::PROMOTIONS[:Flash]) }

  # Forge chain scopes
  scope :in_forge_chain, ->(chain_id) { where(forge_chain_id: chain_id).order(:forge_order) }

  # Forge chain callbacks
  # rubocop:disable-next Rails/ActiveRecordCallbacksOrder -- moving it up would run it before the belongs_to autosaves
  before_save :compute_forge_chain_fields, if: :forged_from_changed?

  # Forge chain methods
  def forged_from_weapon
    return nil if forged_from.blank?

    Weapon.find_by(granblue_id: forged_from)
  end

  def forge_chain(same_element: true)
    return [] if forge_chain_id.blank?

    chain = Weapon.in_forge_chain(forge_chain_id)
    same_element ? chain.where(element: element) : chain
  end

  def forges_to(same_element: true)
    weapons = Weapon.where(forged_from: granblue_id)
    same_element ? weapons.where(element: element) : weapons
  end

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
    weapon_series&.slug
  end

  # Virtual attribute to set weapon_series by ID or slug
  # Supports both UUID and slug lookup for flexibility
  def series=(value)
    # Try to find by ID first, then by slug
    self.weapon_series = value.blank? ? nil : (WeaponSeries.find_by(id: value) || WeaponSeries.find_by(slug: value))
  end

  # The game's weapon ids are 10 digits; they also become image filenames.
  GRANBLUE_ID_FORMAT = /\A\d{10}\z/

  # element_variant_ids maps an element id ("0".."6") to the game's weapon id
  # for that element's art. The ids become image filenames, so only plain
  # 10-digit ids are accepted.
  ELEMENT_VARIANT_KEY_FORMAT = /\A[0-6]\z/
  ELEMENT_VARIANT_ID_FORMAT = GRANBLUE_ID_FORMAT

  # Simple rules the admin schema publishes (GET /admin/weapons/schema), so
  # the editor checks the same things before saving. Null (0) is the element
  # of element-changeable weapons; every weapon has a proficiency, so None (0)
  # is not one.
  RARITY_VALUES = GranblueEnums::RARITIES
  ELEMENT_VALUES = GranblueEnums::ELEMENTS
  PROFICIENCY_VALUES = GranblueEnums::PROFICIENCY.except(:None).freeze
  STAT_COLUMNS = %i[max_level max_skill_level max_exorcism_level
                    min_hp max_hp max_hp_flb max_hp_ulb min_atk max_atk max_atk_flb max_atk_ulb].freeze

  validates :granblue_id, presence: true, format: { with: GRANBLUE_ID_FORMAT }, uniqueness: true
  validates :name_en, presence: true
  validates :rarity, inclusion: { in: RARITY_VALUES.values }
  validates :element, inclusion: { in: ELEMENT_VALUES.values }
  validates :proficiency, inclusion: { in: PROFICIENCY_VALUES.values }
  validates(*STAT_COLUMNS, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true)
  # nil means the weapon has no awakenings; ones that do go to at least level 1.
  validates :max_awakening_level, numericality: { only_integer: true, greater_than_or_equal_to: 1 }, allow_nil: true

  def self.valid_element_variant_ids?(value)
    return true if value.nil?
    return false unless value.is_a?(Hash)

    value.all? do |key, id|
      key.to_s.match?(ELEMENT_VARIANT_KEY_FORMAT) && id.is_a?(String) && id.match?(ELEMENT_VARIANT_ID_FORMAT)
    end
  end

  validate :element_variant_ids_format

  def element_variant_ids_format
    return if self.class.valid_element_variant_ids?(element_variant_ids)

    errors.add(:element_variant_ids, 'must map element ids (0-6) to 10-digit weapon ids')
  end

  # Validation to prevent circular forge chains
  validate :no_circular_forge_chain

  def no_circular_forge_chain
    return if forged_from.blank?

    visited = Set.new([granblue_id])
    current = forged_from

    while current.present?
      if visited.include?(current)
        errors.add(:forged_from, 'creates a circular forge chain')
        return
      end
      visited << current
      current = Weapon.find_by(granblue_id: current)&.forged_from
    end
  end

  private

  # Decided at the save, not the commit: without_skill_build may only wrap the save.
  def capture_skill_build
    @skill_build_pending = !self.class.skip_skill_build &&
                           (saved_change_to_wiki_en? || saved_source_changes.include?('wiki_raw'))
  end

  def skill_inputs_changed?
    return false unless @skill_build_pending

    @skill_build_pending = false
    # The build reads the page by title: without both there's nothing to build from.
    wiki_en.present? && source_sha256(:wiki_raw).present?
  end

  def enqueue_skill_build
    WeaponSkills::BuildJob.perform_later(id)
  end

  # Auto-compute forge_order and forge_chain_id based on forged_from
  # Walks the full chain to the root to ensure correct ordering
  def compute_forge_chain_fields
    if forged_from.present?
      # Walk up the chain to find the root and count depth
      chain = []
      current = Weapon.find_by(granblue_id: forged_from)
      return unless current

      visited = Set.new([granblue_id])
      while current
        break if visited.include?(current.granblue_id)

        chain.unshift(current)
        visited.add(current.granblue_id)

        break if current.forged_from.blank?

        current = Weapon.find_by(granblue_id: current.forged_from)

      end

      # First element is the root
      root = chain.first
      root_chain_id = root.forge_chain_id || root.id
      self.forge_chain_id = root_chain_id
      self.forge_order = chain.length

      # Fix up the entire chain: root and all intermediates
      chain.each_with_index do |weapon, index|
        updates = {}
        updates[:forge_chain_id] = root_chain_id if weapon.forge_chain_id != root_chain_id
        updates[:forge_order] = index if weapon.forge_order != index
        # rubocop:disable-next Rails/SkipsModelValidations -- fixes the other chain rows from this weapon's save; their callbacks must not rerun
        weapon.update_columns(updates.merge(updated_at: Time.current)) if updates.any?
      end
    elsif forge_chain_id.present?
      # Clearing forged_from - reset forge_order if part of a chain
      self.forge_order = 0
    end
  end
end
