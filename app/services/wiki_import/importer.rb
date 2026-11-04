# frozen_string_literal: true

module WikiImport
  ##
  # Turns a gbf.wiki TeamSpread team (already parsed by the web app into a
  # WikiImport::Payload) into a party.
  #
  # Resolution runs first and only reads: it matches wiki titles to catalogue
  # rows and re-checks every identifier the client sent (key ids, bullet slugs,
  # class, subskill and accessory names; the class goes through JobResolver and
  # uncaps through UncapResolver). Both modes then build the party and its grid
  # with PartyBuilder in one transaction; #preview rolls it back, so it reports
  # exactly what #create! would. Everything found goes into one Report.
  #
  # Nothing in a paste is fatal. Unknown values, unmatched titles and grid
  # items the models reject are skipped and reported, and the rest imports.
  class Importer
    # "Ultima Gun (Fire)": a weapon page per element.
    ELEMENT_SUFFIX = /\A(.+) \((Fire|Water|Earth|Wind|Light|Dark)\)\z/

    # TeamSpread key parameter → weapon series that take its keys.
    KEY_SERIES = {
      'opus' => %w[dark-opus],
      'ultima' => %w[ultima],
      'draconic' => %w[draconic draconic-providence],
      'destroyer' => %w[destroyer],
      'ccw' => %w[class-champion]
    }.freeze

    CHARACTER_AWAKENINGS = {
      'attack' => 'character-atk',
      'defense' => 'character-def',
      'multiattack' => 'character-multi'
    }.freeze

    WEAPON_AWAKENINGS = {
      'attack' => 'weapon-atk',
      'defense' => 'weapon-def',
      'special' => 'weapon-special',
      'ca' => 'weapon-ca',
      'skill' => 'weapon-skill',
      'heal' => 'weapon-heal',
      'multiattack' => 'weapon-multi'
    }.freeze

    POSITIONS = {
      character: 0..7,
      weapon: -1..11,
      summon: -1..6
    }.freeze

    MODELS = { character: Character, weapon: Weapon, summon: Summon }.freeze

    MAX_CANDIDATES = 10
    FULL_AUTO_SLOTS = (0..3)

    # The full auto settings for the slots turned off; other slots are ignored.
    #
    # @param slots [Array<Integer>]
    # @return [Hash{String => false}]
    def self.full_auto_skills(slots)
      slots.select { |slot| FULL_AUTO_SLOTS.cover?(slot) }.to_h { |slot| [slot.to_s, false] }
    end

    ##
    # @param payload [WikiImport::Payload]
    # @param user [User, nil] the party's owner; nil makes an anonymous party.
    def initialize(payload, user: nil)
      @payload = payload
      @user = user
      @report = Report.new
      @uncaps = UncapResolver.new(@report)
    end

    ##
    # Resolves the paste and reports what would import. Runs the same build
    # as #create! and rolls it back, so the grid models' rejections show up
    # here too and both modes report the same warnings. Nothing persists:
    # the build's only side effects outside the database are after_commit
    # callbacks, which a rollback never runs.
    #
    # @return [Hash] the report.
    def preview
      resolve
      ActiveRecord::Base.transaction(requires_new: true) do
        build_party
        raise ActiveRecord::Rollback
      end
      @report.to_h
    end

    ##
    # Resolves the paste and creates the party.
    #
    # @return [Array(Party, Hash)] the party and the report.
    def create!
      resolve
      party = nil
      ActiveRecord::Base.transaction(requires_new: true) { party = build_party }
      [party, @report.to_h]
    end

    private

    def build_party
      plan = { job: @job, characters: @characters, summons: @summons, weapons: @weapons, bullets: @bullets }
      PartyBuilder.new(plan, payload: @payload, user: @user, report: @report).build
    end

    def resolve
      @job = JobResolver.new(@payload.job, @report).resolve
      @characters = resolve_items(:character, @payload.characters)
      @weapons = resolve_items(:weapon, @payload.weapons)
      @summons = resolve_items(:summon, @payload.summons)
      resolve_keys
      resolve_bullets
    end

    def resolve_items(kind, entries)
      taken = Set.new
      entries.filter_map do |entry|
        unless POSITIONS[kind].cover?(entry.position)
          @report.warn('invalid_position', "#{kind} #{entry.position}", **Report.at(kind, entry))
          next
        end
        unless taken.add?(entry.position)
          @report.warn('slot_conflict', "#{kind} #{entry.position}", **Report.at(kind, entry))
          next
        end

        record, element = resolve_title(kind, entry)
        next unless record

        plan = send(:"plan_#{kind}", entry, record, element)
        @report.matched(kind, entry.position, entry.title, Report.item_json(record, plan[:element]))
        plan
      end
    end

    # Exact wiki_en, then exact name_en; weapons then retry without an element
    # suffix. More than one row is ambiguous: never pick one silently.
    def resolve_title(kind, entry)
      title = Granblue::WikiTitle.normalize(entry.title)
      rows = lookup(kind, title)
      element = nil
      if rows.empty? && kind == :weapon && (match = ELEMENT_SUFFIX.match(title.to_s))
        rows = lookup(kind, match[1])
        element = GranblueEnums::ELEMENTS[match[2].to_sym]
      end

      case rows.size
      when 0
        @report.unmatched(kind, entry)
        nil
      when 1
        [rows.first, element]
      else
        @report.ambiguous(kind, entry, rows.first(MAX_CANDIDATES).map { |row| Report.item_json(row, row.element) })
        nil
      end
    end

    def lookup(kind, title)
      return [] if title.blank?

      scope = MODELS[kind]
      scope = scope.includes(:weapon_series, :weapon_series_variant, :awakenings) if kind == :weapon
      rows = scope.where(wiki_en: title).limit(MAX_CANDIDATES + 1).to_a
      rows = scope.where(name_en: title).limit(MAX_CANDIDATES + 1).to_a if rows.empty?
      rows
    end

    def plan_character(entry, record, _element)
      uncap, step = @uncaps.resolve(:character, entry, record)
      {
        entry: entry, record: record, element: record.element,
        uncap: uncap, step: step,
        awakening: character_awakening(entry),
        ring: entry.ring,
        full_auto_skills: self.class.full_auto_skills(entry.full_auto_off)
      }
    end

    def plan_weapon(entry, record, element)
      if element && !record.effective_element_changeable
        @report.warn('element_not_changeable', "weapon #{entry.position}", **Report.at(:weapon, entry))
        element = nil
      end
      uncap, step = @uncaps.resolve(:weapon, entry, record)
      {
        entry: entry, record: record, element: element,
        uncap: uncap, step: step,
        awakening: weapon_awakening(entry, record),
        keys: {}
      }
    end

    def plan_summon(entry, record, _element)
      uncap, step = @uncaps.resolve(:summon, entry, record)
      { entry: entry, record: record, element: record.element, uncap: uncap, step: step }
    end

    def character_awakening(entry)
      return nil if entry.awakening.nil?

      slug = CHARACTER_AWAKENINGS[entry.awakening]
      awakening = slug && Awakening.find_by(slug: slug, object_type: 'Character')
      @report.warn('unknown_awakening', entry.awakening, **Report.at(:character, entry)) unless awakening
      awakening
    end

    def weapon_awakening(entry, record)
      return nil if entry.awakening.nil?

      slug = WEAPON_AWAKENINGS[entry.awakening]
      return @report.warn('unknown_awakening', entry.awakening, **Report.at(:weapon, entry)) unless slug

      awakening = record.awakenings.find { |a| a.slug == slug } if record.effective_has_awakening
      @report.warn('awakening_not_allowed', entry.awakening, **Report.at(:weapon, entry)) unless awakening
      awakening
    end

    # Keys are looked up within the group's series, so an id from another
    # series is unknown here. A key must sit in its own slot.
    def resolve_keys
      @payload.key_sets.each do |group, ids|
        slugs = KEY_SERIES[group]
        unless slugs
          @report.warn('unknown_key', group, kind: 'key', title: group)
          next
        end

        keys = ids.each_with_index.filter_map do |id, slot|
          next if id.nil?

          key = find_key(slugs, id)
          if key.nil? || key.slot != slot
            @report.warn('unknown_key', "#{group} slot #{slot}", kind: 'key', position: slot, title: id.to_s)
            next
          end
          @report.matched('key', slot, id.to_s, Report.named_json(key))
          key
        end
        apply_keys(slugs, keys)
      end
    end

    def find_key(slugs, granblue_id)
      in_series = WeaponKeySeries.joins(:weapon_series).where(weapon_series: { slug: slugs }).select(:weapon_key_id)
      WeaponKey.includes(:weapon_series).find_by(granblue_id: granblue_id, id: in_series)
    end

    # The template keeps one set of keys per series; every weapon of the series
    # that takes keys gets them, where the key fits that weapon's series.
    def apply_keys(slugs, keys)
      @weapons.each do |plan|
        weapon = plan[:record]
        next unless slugs.include?(weapon.weapon_series&.slug) && weapon.effective_has_weapon_keys

        keys.each do |key|
          plan[:keys][key.slot] = key if key.weapon_series.any? { |series| series.id == weapon.weapon_series_id }
        end
      end
    end

    # Bullets go on the mainhand, each in the first free slot of its type, in
    # the order sent.
    def resolve_bullets
      @bullets = []
      return if @payload.bullets.empty?

      known = Bullet.where(slug: @payload.bullets).index_by(&:slug)
      bullets = @payload.bullets.each_with_index.filter_map do |slug, index|
        bullet = known[slug]
        unless bullet
          @report.warn('unknown_bullet', slug, kind: 'bullet', position: index, title: slug)
          next
        end
        @report.matched('bullet', index, slug, Report.named_json(bullet))
        [bullet, index]
      end
      place_bullets(bullets)
    end

    def place_bullets(bullets)
      return if bullets.empty?

      mainhand = @weapons.find { |plan| plan[:entry].position == -1 }
      slots = mainhand ? Array(mainhand[:record].bullet_slots) : []
      if slots.empty?
        @report.warn('invalid_item', 'bullets: the mainhand takes no bullets', kind: 'bullet')
        return
      end

      free = slots.each_index.to_a
      bullets.each do |bullet, index|
        slot = free.find { |free_slot| slots[free_slot] == bullet.bullet_type }
        if slot
          free.delete(slot)
          @bullets << [bullet, slot, index]
        else
          @report.warn('invalid_item', "bullet #{bullet.slug}: no free slot",
                       kind: 'bullet', position: index, title: bullet.slug)
        end
      end
    end
  end
end
