# frozen_string_literal: true

module SummonAuras
  # Turns one summon's stored wiki_raw into its aura rows: Granblue::Extractors::SummonAuraExtractor
  # (pure) → Build::Writer (upsert by natural key). Build::Runner drives it; Build::Fingerprint
  # decides which summons are stale.
  module Build
    # Bump whenever the builder's output changes on purpose: every summon becomes stale and
    # the next deploy rebuilds it.
    VERSION = 1

    ELEMENT_WORD = GranblueEnums::ELEMENT_ENUM.invert.transform_values(&:to_s).freeze

    # The natural key of a summon_auras row, and the columns the build writes. description_jp
    # isn't built yet, so the writer leaves it alone.
    KEY = %w[summon_granblue_id slot uncap_level transcendence_stage].freeze
    COLUMNS = %w[target element value condition description_en].freeze

    module_function

    # summon: a Summon (granblue_id, element, summon_series, wiki_raw). → its aura records as
    # string-keyed hashes (KEY + COLUMNS), sorted by key. Pure: no writes, no network.
    def for(summon)
      Granblue::Extractors::SummonAuraExtractor.new.extract(
        summon.wiki_raw,
        granblue_id: summon.granblue_id,
        series: summon.summon_series&.slug,
        element: ELEMENT_WORD[summon.element]
      ).map { |record| record.transform_keys(&:to_s) }
       .sort_by { |record| record.values_at(*KEY) }
    end
  end
end
