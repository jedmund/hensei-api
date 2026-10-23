# frozen_string_literal: true

module WikiImport
  ##
  # Turns a gbf.wiki TeamSpread team (already parsed by the web app into a
  # WikiImport::Payload) into a party.
  #
  # Resolution runs first and only reads: it matches wiki titles to catalogue
  # rows and re-checks every identifier the client sent (key ids, bullet slugs,
  # class, subskill and accessory names). #preview stops there. #create! then
  # builds the party and its grid in one transaction.
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

    # Rows 4, 5 and ex2 take at most two subskills of each kind.
    LIMITED_SKILL_ROWS = %w[4 5 ex2].freeze
    MAX_SKILLS_OF_TYPE = 2

    MAX_CANDIDATES = 10
    FULL_AUTO_SLOTS = (0..3)

    ##
    # @param payload [WikiImport::Payload]
    # @param user [User, nil] the party's owner; nil makes an anonymous party.
    def initialize(payload, user: nil)
      @payload = payload
      @user = user
      @report = { matched: [], unmatched: [], ambiguous: [], warnings: [] }
    end

    ##
    # Resolves the paste and reports what would import. Writes nothing.
    #
    # @return [Hash] the report.
    def preview
      resolve
      @report
    end

    ##
    # Resolves the paste and creates the party.
    #
    # @return [Array(Party, Hash)] the party and the report.
    def create!
      resolve
      party = nil
      ActiveRecord::Base.transaction do
        party = create_party
        @characters.each { |plan| create_character(party, plan) }
        @summons.each { |plan| create_summon(party, plan) }
        @weapons.each { |plan| create_weapon(party, plan) }
        # Party's after_commit callbacks read these; drop anything cached mid-import.
        party.characters.reset
        party.weapons.reset
        party.summons.reset
      end
      [party, @report]
    end

    private

    # ---------------------------------------------------------------- resolve

    def resolve
      resolve_job
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
          add_warning('invalid_position', "#{kind} #{entry.position}")
          next
        end
        unless taken.add?(entry.position)
          add_warning('slot_conflict', "#{kind} #{entry.position}")
          next
        end

        record, element = resolve_title(kind, entry)
        next unless record

        plan = send(:"plan_#{kind}", entry, record, element)
        @report[:matched] << { kind: kind.to_s, position: entry.position, title: entry.title,
                               item: item_json(record, plan[:element]) }
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
        @report[:unmatched] << { kind: kind.to_s, position: entry.position, title: entry.title }
        nil
      when 1
        [rows.first, element]
      else
        @report[:ambiguous] << { kind: kind.to_s, position: entry.position, title: entry.title,
                                 candidates: rows.first(MAX_CANDIDATES).map { |row| item_json(row, row.element) } }
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
      uncap, step = resolve_uncap(:character, entry, record)
      {
        entry: entry, record: record, element: record.element,
        uncap: uncap, step: step,
        awakening: character_awakening(entry),
        ring: entry.ring,
        full_auto_skills: full_auto_skills(entry.full_auto_off)
      }
    end

    def plan_weapon(entry, record, element)
      if element && !record.effective_element_changeable
        add_warning('element_not_changeable', "weapon #{entry.position}")
        element = nil
      end
      uncap, step = resolve_uncap(:weapon, entry, record)
      {
        entry: entry, record: record, element: element,
        uncap: uncap, step: step,
        awakening: weapon_awakening(entry, record),
        keys: {}
      }
    end

    def plan_summon(entry, record, _element)
      uncap, step = resolve_uncap(:summon, entry, record)
      { entry: entry, record: record, element: record.element, uncap: uncap, step: step }
    end

    # "0"-"5" stars, "t1"-"t5" (uncap 6 at that transcendence step; "6" is t5),
    # or nil for the item's max. Values past the item's max are lowered to it.
    def resolve_uncap(kind, entry, record)
      max_uncap, max_step = max_uncap(kind, record, explicit: !entry.uncap.nil?)
      return [max_uncap, max_step] if entry.uncap.nil?

      uncap, step = parse_uncap(entry.uncap)
      if uncap.nil?
        add_warning('invalid_uncap', "#{kind} #{entry.position}")
        return [max_uncap, max_step]
      end

      if uncap > max_uncap || step > max_step
        add_warning('uncap_clamped', "#{kind} #{entry.position}")
        uncap = [uncap, max_uncap].min
        step = uncap == 6 ? [step, max_step].min : 0
      end
      [uncap, step]
    end

    def parse_uncap(value)
      case value
      when /\A[0-5]\z/ then [value.to_i, 0]
      when '6' then [6, 5]
      when /\At([1-5])\z/ then [6, Regexp.last_match(1).to_i]
      end
    end

    # [uncap_level, transcendence_step] at the item's max. A Dark Opus weapon
    # left at the template's default is 5★: the wiki export omits its uncap
    # there, even though it can transcend.
    def max_uncap(kind, record, explicit:)
      if kind == :character
        uncap = record.max_uncap_level
        return [uncap, uncap == 6 ? record.max_transcendence_stage : 0]
      end

      return [5, 0] if !explicit && kind == :weapon && record.weapon_series&.slug == WeaponSeries::DARK_OPUS
      return [6, 5] if record.transcendence
      return [5, 0] if record.ulb
      return [4, 0] if record.flb

      [3, 0]
    end

    def character_awakening(entry)
      return nil if entry.awakening.nil?

      slug = CHARACTER_AWAKENINGS[entry.awakening]
      awakening = slug && Awakening.find_by(slug: slug, object_type: 'Character')
      add_warning('unknown_awakening', "character #{entry.position}") unless awakening
      awakening
    end

    def weapon_awakening(entry, record)
      return nil if entry.awakening.nil?

      slug = WEAPON_AWAKENINGS[entry.awakening]
      awakening = record.awakenings.find { |a| a.slug == slug } if slug && record.effective_has_awakening
      add_warning('unknown_awakening', "weapon #{entry.position}") unless awakening
      awakening
    end

    def full_auto_skills(slots)
      slots.select { |slot| FULL_AUTO_SLOTS.cover?(slot) }.to_h { |slot| [slot.to_s, false] }
    end

    # Keys are looked up within the group's series, so an id from another
    # series is unknown here. A key must sit in its own slot.
    def resolve_keys
      @payload.key_sets.each do |group, ids|
        slugs = KEY_SERIES[group]
        unless slugs
          add_warning('unknown_key', group)
          next
        end

        keys = ids.each_with_index.filter_map do |id, slot|
          next if id.nil?

          key = find_key(slugs, id)
          if key.nil? || key.slot != slot
            add_warning('unknown_key', "#{group} slot #{slot}")
            next
          end
          @report[:matched] << { kind: 'key', position: slot, title: id.to_s, item: named_json(key) }
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
          add_warning('unknown_bullet', slug)
          next
        end
        @report[:matched] << { kind: 'bullet', position: index, title: slug, item: named_json(bullet) }
        bullet
      end
      place_bullets(bullets)
    end

    def place_bullets(bullets)
      return if bullets.empty?

      mainhand = @weapons.find { |plan| plan[:entry].position == -1 }
      slots = mainhand ? Array(mainhand[:record].bullet_slots) : []
      if slots.empty?
        add_warning('invalid_item', 'bullets: the mainhand takes no bullets')
        return
      end

      free = slots.each_index.to_a
      bullets.each do |bullet|
        slot = free.find { |index| slots[index] == bullet.bullet_type }
        if slot
          free.delete(slot)
          @bullets << [bullet, slot]
        else
          add_warning('invalid_item', "bullet #{bullet.slug}: no free slot")
        end
      end
    end

    def resolve_job
      @job = @skill0 = @accessory = nil
      @skills = [nil, nil, nil]
      @mc_full_auto = {}
      spec = @payload.job
      return unless spec

      if spec.name.present?
        @job = Job.includes(:base_job).where('LOWER(name_en) = ?', spec.name.strip.downcase).order(:order).first
        if @job
          @report[:matched] << { kind: 'job', position: 0, title: spec.name, item: named_json(@job) }
          @skill0 = JobSkill.find_by(job_id: @job.id, main: true)
        else
          add_warning('unknown_job', spec.name)
        end
      end

      spec.skills.each_with_index { |name, index| resolve_skill(name, index + 1) }
      resolve_accessory(spec.accessory)
      @mc_full_auto = full_auto_skills(spec.full_auto_off) if @job
    end

    # Subskills match by English name among the skills this class may equip.
    def resolve_skill(name, slot)
      return if name.blank?

      skill = @job && skill_for(name)
      unless skill
        add_warning('unknown_skill', name)
        return
      end

      @skills[slot - 1] = skill
      @report[:matched] << { kind: 'skill', position: slot, title: name, item: named_json(skill) }
    end

    def skill_for(name)
      taken = [@skill0, *@skills].compact
      candidates = JobSkill.includes(job: :base_job).where('LOWER(name_en) = ?', name.strip.downcase).to_a
      candidates.reject! { |skill| taken.include?(skill) || skill.incompatible_with?(@job) }
      skill = candidates.find { |s| s.job_id == @job.id } || candidates.first
      skill if skill && room_for_skill?(skill)
    end

    def room_for_skill?(skill)
      return true unless LIMITED_SKILL_ROWS.include?(@job.row)

      type = skill.sub ? :sub : :emp
      @skills.compact.count { |s| s.public_send(type) } < MAX_SKILLS_OF_TYPE
    end

    def resolve_accessory(name)
      return if name.blank?

      if @job&.accessory && @job.accessory_type.to_i.positive?
        @accessory = JobAccessory.where('LOWER(TRIM(name_en)) = ?', name.strip.downcase)
                                 .where(accessory_type: @job.accessory_type).first
      end
      if @accessory
        @report[:matched] << { kind: 'accessory', position: 0, title: name, item: named_json(@accessory) }
      else
        add_warning('unknown_accessory', name)
      end
    end

    # ----------------------------------------------------------------- create

    def create_party
      Party.create!(
        user: @user,
        last_updated: Time.current,
        job: @job,
        skill0: @skill0,
        skill1: @skills[0],
        skill2: @skills[1],
        skill3: @skills[2],
        accessory: @accessory,
        full_auto_skills: @mc_full_auto
      )
    end

    def create_character(party, plan)
      party.characters.reset
      if party.characters.any? { |gc| gc.character_id == plan[:record].id }
        return add_warning('invalid_item', "character #{plan[:entry].position}: already in the party")
      end

      grid_character = GridCharacter.new(
        party: party,
        character: plan[:record],
        position: plan[:entry].position,
        uncap_level: plan[:uncap],
        transcendence_step: plan[:step],
        awakening: plan[:awakening],
        perpetuity: plan[:ring],
        full_auto_skills: plan[:full_auto_skills]
      )
      saved_item?(:character, plan, grid_character)
      nil
    end

    def create_summon(party, plan)
      position = plan[:entry].position
      party.summons.reset
      grid_summon = GridSummon.new(
        party: party,
        summon: plan[:record],
        position: position,
        main: position == -1,
        friend: position == GridSummon::FRIEND_POSITION,
        quick_summon: position == @payload.quick,
        uncap_level: plan[:uncap],
        transcendence_step: plan[:step]
      )
      saved_item?(:summon, plan, grid_summon)
      nil
    end

    def create_weapon(party, plan)
      party.weapons.reset
      grid_weapon = GridWeapon.new(
        party: party,
        weapon: plan[:record],
        position: plan[:entry].position,
        uncap_level: plan[:uncap],
        transcendence_step: plan[:step],
        element: plan[:element],
        awakening: plan[:awakening]
      )
      plan[:keys].each { |slot, key| grid_weapon.public_send(:"weapon_key#{slot + 1}_id=", key.id) }
      return unless saved_item?(:weapon, plan, grid_weapon)

      create_bullets(grid_weapon) if grid_weapon.position == -1
    end

    def create_bullets(grid_weapon)
      @bullets.each do |bullet, slot|
        record = GridWeaponBullet.new(grid_weapon: grid_weapon, bullet: bullet, position: slot)
        next if record.save

        add_warning('invalid_item', "bullet #{bullet.slug}: #{record.errors.full_messages.to_sentence}")
      end
    end

    # A grid item the models reject is skipped with a warning; the rest of the
    # party still imports.
    def saved_item?(kind, plan, record)
      return true if record.save

      add_warning('invalid_item', "#{kind} #{plan[:entry].position}: #{record.errors.full_messages.to_sentence}")
      false
    end

    # ----------------------------------------------------------------- report

    def add_warning(code, detail)
      @report[:warnings] << { code: code, detail: detail }
      nil
    end

    def item_json(record, element)
      named_json(record).merge(element: element)
    end

    def named_json(record)
      json = { id: record.id }
      json[:granblueId] = record.granblue_id if record.respond_to?(:granblue_id)
      json.merge(name: { en: record.name_en, ja: record.name_jp })
    end
  end
end
