# frozen_string_literal: true

module SummonAuras
  # Turns one summon's stored wiki_raw into its aura rows: Granblue::Extractors::SummonAuraExtractor
  # (pure) → Build::Writer (upsert by natural key). Build::Runner drives it; Build::Fingerprint
  # decides which summons are stale.
  module Build
    # Bump whenever the builder's output changes on purpose: every summon becomes stale and
    # the next deploy rebuilds it.
    VERSION = 6

    ELEMENT_WORD = GranblueEnums::ELEMENT_ENUM.invert.transform_values(&:to_s).freeze

    # The natural key of a summon_auras row, and the columns the build writes.
    KEY = %w[summon_granblue_id slot uncap_level transcendence_stage].freeze
    COLUMNS = %w[target element value max_value condition description_en description_jp].freeze

    module_function

    # summon: a Summon (granblue_id, element, summon_series, wiki_raw, wiki_raw_jp). → its aura
    # records as string-keyed hashes (KEY + COLUMNS), sorted by key. Pure: no writes, no network.
    def for(summon)
      jp = Granblue::Extractors::SummonAuraJpExtractor.new
      jp_aura = jp.extract(summon.wiki_raw_jp)
      Granblue::Extractors::SummonAuraExtractor.new.extract(
        summon.wiki_raw,
        granblue_id: summon.granblue_id,
        series: summon.summon_series&.slug,
        element: ELEMENT_WORD[summon.element]
      ).map { |record| record.transform_keys(&:to_s) }
       .each { |record| record['description_jp'] = description_jp(jp, jp_aura, record) }
       .sort_by { |record| record.values_at(*KEY) }
    end

    # The summon's aura name in each language, stored on the summon (one name covers its main
    # and sub aura): English from the page's aura_name; Japanese from the Japanese page's
    # 加護 name cell, else the English page's jpaura_name. Pure.
    def names(summon)
      en_page = Granblue::Extractors::SummonAuraExtractor.new.aura_names(summon.wiki_raw)
      jp_page = Granblue::Extractors::SummonAuraJpExtractor.new.extract(summon.wiki_raw_jp)
      { 'aura_name_en' => en_page[:en], 'aura_name_jp' => jp_page&.name.presence || en_page[:ja] }
    end

    # The Japanese text for one tier, from the summon's gbf-wiki.com page or list row. None for
    # transcendence stages (the wiki doesn't say which stage adds what), and none when the
    # tier has a value the Japanese text doesn't state: the wiki page hasn't caught up with
    # that uncap, and an older number would contradict the English.
    def description_jp(extractor, jp_aura, record)
      return if record['transcendence_stage'].to_i.positive?

      text = extractor.text(jp_aura, record['slot'], record['uncap_level'])
      return text if text.nil? || record['value'].nil?

      states_value?(text, record['value']) ? text : nil
    end

    def states_value?(text, value)
      number = value.to_d.frac.zero? ? value.to_i.to_s : value.to_d.to_s('F')
      text.unicode_normalize(:nfkc).scan(/\d+(?:\.\d+)?/).include?(number)
    end
  end
end
