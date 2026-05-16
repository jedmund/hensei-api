# frozen_string_literal: true

##
# Service for importing a user's profile Support Summon configuration
# (the 22 slots displayed on their GBF profile: 3 per element + 4 misc).
#
# Accepts the raw payload extracted by the Chrome extension's HTML parser:
#
#   [
#     { gbf_section: 1, position: 0, granblue_id: "2040094000", level: 250 },
#     { gbf_section: 0, position: 0, granblue_id: "2040158000", level: 100 },
#     ...
#   ]
#
# - `gbf_section` uses Granblue's element ordering (0=Misc/Null, 1=Fire, 2=Water,
#   3=Earth, 4=Wind, 5=Light, 6=Dark) and is translated to our internal
#   SupportSummon section enum.
# - `level` is the in-game level scraped from the profile HTML. Used only when
#   auto-creating a missing CollectionSummon — existing rows are not touched, on
#   the assumption the user's collection import is more authoritative.
#
# Replacement is atomic: all existing SupportSummon rows are destroyed and the
# new set is inserted inside a single transaction. Any validation failure rolls
# the whole import back.
#
class SupportSummonImportService
  Result = Struct.new(:success?, :created, :errors, keyword_init: true)

  # GBF section index → SupportSummon enum symbol.
  # 0 is GBF's Null/None bucket, which we use for the Misc section.
  SECTION_MAP = {
    0 => :misc,
    1 => :fire,
    2 => :water,
    3 => :earth,
    4 => :wind,
    5 => :light,
    6 => :dark
  }.freeze

  def initialize(user, items)
    @user = user
    @items = items.is_a?(Array) ? items : []
    @created = []
    @errors = []
  end

  ##
  # Derives `[uncap_level, transcendence_step]` from an in-game summon level.
  # GBF doesn't expose the raw uncap fields on the profile page, but level
  # uniquely determines them.
  def self.derive_uncap(level)
    level = level.to_i
    return [0, 0] if level <= 40
    return [1, 0] if level <= 60
    return [2, 0] if level <= 80
    return [3, 0] if level <= 100
    return [4, 0] if level <= 150
    return [5, 0] if level <= 200

    # 201–250: uncap 6, transcendence_step 1–5 in 10-level buckets
    transcendence = ((level - 200) / 10.0).ceil.clamp(1, 5)
    [6, transcendence]
  end

  def import
    ActiveRecord::Base.transaction do
      @user.support_summons.destroy_all

      @items.each_with_index do |item, index|
        import_item(item, index)
      end

      raise ActiveRecord::Rollback if @errors.any?
    end

    Result.new(success?: @errors.empty?, created: @created, errors: @errors)
  end

  private

  def import_item(item, index)
    granblue_id = item['granblue_id'].to_s
    gbf_section = item['gbf_section']
    position = item['position']
    level = item['level']

    section = SECTION_MAP[gbf_section.to_i]
    if section.nil?
      @errors << { index: index, granblue_id: granblue_id, error: "Unknown GBF section #{gbf_section.inspect}" }
      return
    end

    summon = find_summon(granblue_id)
    unless summon
      @errors << { index: index, granblue_id: granblue_id, error: 'Summon not found' }
      return
    end

    collection_summon = find_or_create_collection_summon(summon, level)
    return if collection_summon.nil? # error already pushed

    row = @user.support_summons.build(
      collection_summon: collection_summon,
      section: section,
      position: position
    )

    if row.save
      @created << row
    else
      @errors << {
        index: index,
        granblue_id: granblue_id,
        error: row.errors.full_messages.join(', ')
      }
    end
  end

  def find_summon(granblue_id)
    Summon.find_by(granblue_id: granblue_id) ||
      Summon.find_by(granblue_id: SummonIdMapping.resolve(granblue_id))
  end

  # Users can only set summons they own in-game, so a missing CollectionSummon
  # row means the user just hasn't run a collection import recently. Create one
  # with the level-derived uncap/transcendence so the support summon resolves.
  # Existing rows are not modified — collection import is the authoritative
  # source for uncap state.
  def find_or_create_collection_summon(summon, level)
    existing = @user.collection_summons.find_by(summon_id: summon.id)
    return existing if existing

    uncap_level, transcendence_step = self.class.derive_uncap(level)
    # If the summon doesn't support transcendence, clamp transcendence_step to 0
    # so we don't trip the validate_transcendence_requirements validation.
    transcendence_step = 0 unless summon.transcendence

    cs = @user.collection_summons.build(
      summon: summon,
      uncap_level: uncap_level,
      transcendence_step: transcendence_step
    )

    unless cs.save
      @errors << {
        granblue_id: summon.granblue_id,
        error: "Could not create collection summon: #{cs.errors.full_messages.join(', ')}"
      }
      return nil
    end

    cs
  end
end
