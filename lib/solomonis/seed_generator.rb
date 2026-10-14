# frozen_string_literal: true

require 'json'

module Solomonis
  # Builds the Evoking Solomonis seed files in db/seed/solomonis/ from the gbf.wiki
  # "Evoking Solomonis" page and the captured guide-effect snapshots. Re-runnable: the
  # guide effects' game fields come from the snapshot file (or the existing seed when no
  # snapshot file is given), and only the wiki-derived fields are recomputed.
  class SeedGenerator
    BLESSINGS = [
      ['justice', 'Justice'],
      ['hanged_man', 'The Hanged Man'],
      ['death', 'Death'],
      ['temperance', 'Temperance'],
      ['devil', 'The Devil'],
      ['tower', 'The Tower'],
      ['star', 'The Star'],
      ['moon', 'The Moon'],
      ['sun', 'The Sun'],
      ['judgement', 'Judgement']
    ].freeze
    FIRST_ARCANA_NUMBER = 11

    # Each blessing's effect in the game's Japanese, from in-game screenshots. `%d` takes the
    # level's value from its English text ("(2 times)", "by 3 turns", "100 Sephira coins").
    # Justice's isn't known yet.
    BLESSING_DESCRIPTIONS_JP = {
      'hanged_man' => '任意のキャラを1人編成可能にする',
      'death' => '%d回まで戦闘マスに出現する敵のHPが1になる',
      'temperance' => '回復マスで味方全体のアビリティと召喚石の再使用間隔を%dターン短縮',
      'devil' => 'セフィラコインを%d獲得する'
    }.freeze

    # Game weapon kind -> Hensei proficiency.
    WEAPON_KIND_TO_PROFICIENCY = { 1 => 1, 2 => 2, 3 => 4, 4 => 3, 5 => 6, 6 => 9, 7 => 7, 8 => 5, 9 => 8, 10 => 10 }.freeze
    TARGET_TYPES = { 'race' => 'race', 'weapon_kind' => 'proficiency', 'proficiency' => 'proficiency', 'character' => 'character' }.freeze

    # Route Evokers' elements (decision D4), to pick the Evoker version among characters sharing a short id.
    EVOKER_ELEMENTS = { 3099 => 3, 3100 => 2, 3102 => 1, 3103 => 4, 3108 => 5 }.freeze

    MATCH_THRESHOLD = 0.55

    # Wiki availability filter values -> seed values (global|event|character).
    AVAILABILITY = { 'global' => 'global', 'event' => 'event', 'specialevent' => 'event', 'character' => 'character' }.freeze

    # status_id => wiki effect text prefix, for effects the text similarity gets wrong.
    # Use :none to force "no wiki match".
    MANUAL_MATCHES = {}.freeze

    attr_reader :report

    def initialize(wikitext:, effects:)
      @wikitext = wikitext
      @effects = effects
      @report = []
    end

    def blessings
      tabs = parse_blessing_tabs
      entries = BLESSINGS.each_with_index.map do |(slug, name_en), index|
        levels = tabs.fetch(name_en) { raise "Blessing tab not found on the wiki: #{name_en}" }
        {
          slug: slug,
          arcana_number: FIRST_ARCANA_NUMBER + index,
          name_en: name_en,
          name_jp: summon_name_jp(name_en),
          released: levels.any?,
          levels: levels.map { |level| level.merge(description_jp: description_jp(slug, level[:description_en])) }
        }
      end
      { _source: 'gbf.wiki "Evoking Solomonis" (Arcarum Blessings); name_jp from the matching Arcarum summon; ' \
                 'description_jp from in-game screenshots',
        blessings: entries }
    end

    def guide_effects
      rows = parse_guidebook_rows
      entries = @effects.map { |effect| guide_effect_entry(effect, rows) }
      { _source: 'Game status_list snapshots (docs/modeling/samples/solomonis-guide-effects-en.json); ' \
                 'availability and tags matched from gbf.wiki "Evoking Solomonis" guidebook tables',
        guide_effects: entries }
    end

    def self.names
      {
        content_mode: 'solomonis',
        raid_group: { name_en: 'Evoking Solomonis', name_jp: 'ソロモナスの賢者' },
        zones: [
          { slug: 'allotropic-microcosm', name_en: 'Allotropic Microcosm', name_jp: '異転律の小世界', create_now: true },
          { slug: 'paracyclic-microcosm', name_en: 'Paracyclic Microcosm', name_jp: '奇巡律の小世界', create_now: true }
        ]
      }
    end

    # Text helpers ----------------------------------------------------------

    def self.strip_markup(text)
      out = text.dup
      # Reduce innermost templates first so nested ones ({{tt|…{{ClassSkill|…}}…}}) resolve.
      loop do
        replaced = out.gsub(/\{\{([^{}]*)\}\}/) { template_text(Regexp.last_match(1)) }
        break if replaced == out

        out = replaced
      end
      out = out.gsub(/\[\[(?:[^\]|]*\|)?([^\]]*)\]\]/, '\1')
      out = out.gsub(%r{<br\s*/?>}i, ' ').gsub(/<[^>]+>/, '').gsub(/'{2,}/, '')
      out.gsub(/\s+/, ' ').strip
    end

    def self.template_text(body)
      name, *args = body.split('|').map(&:strip)
      case name
      when 'tt', 'status' then args.first.to_s
      when 'CharacterSupportSkill' then "#{args.first} support skill"
      when 'CharacterSkill' then "#{args.first} skill"
      else ''
      end
    end

    def self.similarity(left, right)
      a = tokens(left)
      b = tokens(right)
      return 0.0 if a.empty? || b.empty?

      word = dice(a, b)
      tri = dice(trigrams(a.join(' ')), trigrams(b.join(' ')))
      (word + tri) / 2.0
    end

    def self.tokens(text)
      text.downcase.gsub('{value}', ' ').gsub("can't be stacked", ' ')
          .gsub(/(\d),(\d)/, '\1\2').scan(/[a-z]+|\d+/)
    end

    def self.trigrams(text)
      (0..(text.length - 3)).map { |i| text[i, 3] }
    end

    def self.dice(left, right)
      l = left.tally
      r = right.tally
      shared = l.sum { |key, count| [count, r.fetch(key, 0)].min }
      (2.0 * shared) / (left.size + right.size)
    end

    private

    def parse_blessing_tabs
      section = @wikitext[%r{=Arcarum Blessings=(.*?)</tabber>}m, 1] or raise 'Arcarum Blessings section not found'
      section.split(/^\|-\|/).drop(1).to_h do |tab|
        title, body = tab.split('=', 2)
        [title.strip, parse_blessing_levels(body)]
      end
    end

    def parse_blessing_levels(body)
      body.lines.filter_map do |line|
        cells = line.strip.delete_prefix('|').split('||').map(&:strip)
        next unless cells.size == 4 && cells[0].match?(/\A\d+\z/)
        next unless cells[2].match?(/\A\d+\z/) # unreleased blessings show "--"

        { level: cells[0].to_i, description_en: self.class.strip_markup(cells[1]), description_jp: nil,
          cost: cells[2].to_i, scintillas: cells[3].delete(',').to_i }
      end
    end

    def description_jp(slug, description_en)
      template = BLESSING_DESCRIPTIONS_JP[slug] or return nil
      return template unless template.include?('%d')

      value = description_en.to_s.scan(/\d+/).last or return nil
      format(template, value.to_i)
    end

    def summon_name_jp(name_en)
      Summon.where(name_en: name_en).order(:granblue_id).pick(:name_jp).presence
    end

    def parse_guidebook_rows
      section = @wikitext[/^=Guidebooks=(.*?)^=[^=]/m, 1] or raise 'Guidebooks section not found'
      section.scan(/\{\{GuidebookFilter(.*?)\}\}[^\n]*\n\|[^\n]*?\|\|([^\n]*)/m).map do |filter, text|
        fields = filter.scan(/^\|(\w+)=([^\n]*)/).to_h { |k, v| [k, v.split(',').map(&:strip).reject(&:empty?)] }
        { rarity: fields['rarity'] || [], availability: AVAILABILITY.fetch(fields.fetch('availability', ['global']).first),
          type_tags: fields['type'] || [], effect_tags: fields['effects'] || [],
          text: self.class.strip_markup(text) }
      end
    end

    def guide_effect_entry(effect, rows)
      target_type = effect['target_type'] && TARGET_TYPES.fetch(effect['target_type'])
      row = match_row(effect, rows)
      {
        granblue_id: effect.fetch('status_id') { effect.fetch('granblue_id') },
        rarity: effect['rarity'], stackable: effect['stackable'],
        name_en: effect['name_en'], name_jp: effect['name_jp'],
        icon_category: effect['icon_category'], icon_type: effect['icon_type'],
        target_type: target_type,
        target_values: target_values(effect['target_type'], effect['target_values']),
        character_granblue_id: target_type == 'character' ? evoker_granblue_id(effect['target_values'].first) : nil,
        availability: row&.fetch(:availability),
        type_tags: row&.fetch(:type_tags),
        effect_tags: row&.fetch(:effect_tags)
      }
    end

    def target_values(type, values)
      values = Array(values).map(&:to_i)
      type == 'weapon_kind' ? values.map { |v| WEAPON_KIND_TO_PROFICIENCY.fetch(v) } : values
    end

    def evoker_granblue_id(short_id)
      scope = Character.where('? = ANY(character_id)', short_id)
      element = EVOKER_ELEMENTS[short_id]
      scope = scope.where(element: element) if element
      ids = scope.pluck(:granblue_id)
      raise "Expected one Evoker for character_id #{short_id}, found #{ids.inspect}" unless ids.size == 1

      ids.first
    end

    def match_row(effect, rows)
      id = effect.fetch('status_id') { effect.fetch('granblue_id') }
      candidates = rows.select { |row| row[:rarity].include?(effect['rarity']) }
      manual = MANUAL_MATCHES[id]
      return record(id, effect, nil, nil, 'manual: none') if manual == :none
      return manual_row(id, effect, candidates, manual) if manual

      scored = candidates.map { |row| [row, self.class.similarity(effect['name_en'], row[:text])] }.max_by(2, &:last)
      best, score = scored.first
      runner_up = scored[1]&.last || 0.0
      return record(id, effect, nil, score, 'unmatched') if best.nil? || score < MATCH_THRESHOLD

      record(id, effect, best, score, score - runner_up < 0.05 ? 'ambiguous' : 'matched')
    end

    def manual_row(id, effect, candidates, prefix)
      row = candidates.find { |r| r[:text].start_with?(prefix) } or raise "Manual match for #{id} not found: #{prefix}"
      record(id, effect, row, nil, 'manual')
    end

    def record(id, effect, row, score, verdict)
      @report << { id: id, verdict: verdict, score: score&.round(2), game: effect['name_en'], wiki: row&.fetch(:text) }
      ['unmatched', 'manual: none'].include?(verdict) ? nil : row
    end
  end
end
