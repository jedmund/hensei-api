# frozen_string_literal: true

module WeaponSkills
  # The skills a weapon's keys give it, read from the weapon's stored wiki expansion.
  #
  # A keyed weapon's skill table lists each key option under the skill it fills: an
  # "Alternate skill N: Use [[…|α Pendulum]] to pick this skill" row, the option's skill,
  # then "Alternate skill N at level 210" rows before each upgrade. The structure build
  # drops those rows (they aren't the weapon's own tiers); this keeps them, per key, for
  # display (WeaponKeySkill). Reads only the source store, never the live wiki.
  module KeyOptions
    TR = %r{<tr\b([^>]*)>(.*?)</tr>}m
    SKILL = %r{<td class="skill-name"[^>]*>(.*?)</td>.*?<td class="skill-desc"[^>]*>(.*?)</td>}m
    ICON = /\[\[File:([^|\]]+?)\.png/i
    # [[Ultima_Weapons#Gauph_Keys|Gauph Key of Will]] or [[Anklet of Oblivion]]
    USE = /Use \[\[(?:[^\]|]*\|)?([^\]|]+)\]\]/
    OPTION = /Alternate skill (\d+)(?: at level (\d+))?/i

    Summary = Struct.new(:weapons, :keys, :unmatched, :failed, keyword_init: true)

    module_function

    # → [{ key_name:, versions: [{ name_en:, description_en:, icon:, unlock_level:,
    #      min_uncap:, transcendence_stage: }] }], in page order
    def parse(html)
      section = html[/weapon-skills.*/m] || html
      options = []
      current = nil
      pending = nil # the marker row just before a skill row
      section.scan(TR) do |_attrs, body|
        if (marker = body.match(OPTION))
          if marker[2] # an upgrade of the current option
            pending = { level: marker[2].to_i }
          else
            current = { key_name: body[USE, 1]&.strip, versions: [] }
            options << current
            pending = { level: nil }
          end
          next
        end

        skill = body.match(SKILL) or next
        if pending && current
          current[:versions] << version(skill, body, pending[:level])
        else
          current = nil # a base skill row ends the options above it
        end
        pending = nil
      end
      options.select { |o| o[:key_name].present? && o[:versions].any? }
    end

    def version(skill, body, level)
      {
        name_en: Build::Structure::Expanded.clean(skill[1]),
        description_en: wikitext(skill[2]).presence,
        icon: icon_stem(body[ICON, 1]),
        unlock_level: level
      }.merge(Build::Structure::Tiers.tier_for(level))
    end

    # The description cell → wikitext WikiMarkup renders as base skill text is. The expansion's
    # HTML tooltips (statuses with their strength and duration, "Various buffs") go back to
    # {{tt|label|tip}}; file images go; refs and other tags WikiMarkup already drops.
    def wikitext(html)
      text = to_wiki(Nokogiri::HTML::DocumentFragment.parse(html))
      text.gsub(/\[\[(?:File|Image):[^\]]*\]\]/i, '').gsub(/[ \t]+/, ' ').strip
    end

    def to_wiki(node)
      return node.text if node.text?

      inner = -> { node.children.map { |child| to_wiki(child) }.join }
      classes = node['class'].to_s.split
      case node.name
      when 'br' then '<br />'
      when 'ref', 'sup' then ''
      when 'strong', 'b' then "'''#{inner.call}'''"
      when 'span'
        if classes.include?('hr') then '<br />'
        elsif classes.include?('skill-upgrade-text') then "'''#{inner.call}'''"
        elsif classes.include?('tooltip') then tooltip(node)
        else inner.call
        end
      else inner.call
      end
    end

    def tooltip(node)
      tip_node = node.children.find { |c| c.element? && c['class'].to_s.split.include?('tooltiptext') }
      label = node.children.reject { |c| c == tip_node }.map { |c| to_wiki(c) }.join.strip
      return label unless tip_node

      tip = tip_node.children.map { |c| to_wiki(c) }.join.strip
      "{{tt|#{label}|#{tip}}}"
    end

    # "ws_skill_normal_limit_2" → "skill_normal_limit_2"; "Ws skill job weapon" → "skill_job_weapon"
    def icon_stem(file)
      return nil if file.blank?

      file.strip.downcase.sub(/\Aws[ _]/, '').tr(' ', '_')
    end

    # Writes every keyed weapon's key skills from the stored expansions. Idempotent: a
    # weapon's rows are replaced only when they changed, and rows for keys its page no
    # longer lists are removed. Weapons without a stored expansion keep what they have.
    # A weapon that raises keeps its rows too (its savepoint rolls back); it's logged and
    # counted, and the run moves on, so one bad page can't stop the rest.
    def build(store: SourceStore::Database.new, io: $stdout)
      summary = Summary.new(weapons: 0, keys: 0, unmatched: [], failed: [])
      keys_by_name = WeaponKey.all.index_by { |k| k.name_en.to_s.downcase }

      keyed_weapons.find_each do |weapon|
        found = build_weapon(weapon, store, keys_by_name, summary)
        next if found.nil?

        summary.weapons += 1
        summary.keys += found
      rescue StandardError => e
        summary.failed << weapon.granblue_id
        io.puts "#{weapon.granblue_id} #{weapon.name_en}: #{e.class}: #{e.message.lines.first&.strip}"
      end

      io.puts summary_line(summary)
      summary
    end

    # The deploy hook (Runner.deploy, after the weapon-skill build): never raises, so a
    # failure here can't block a release. The table is display-only.
    def deploy(io: $stdout)
      build(io: io)
    rescue StandardError => e
      io.puts "Weapon key skills failed; the deploy continues: #{e.class}: #{e.message}"
      nil
    end

    # → the number of keys written, or nil when the weapon has no stored expansion or no
    # matched key options
    def build_weapon(weapon, store, keys_by_name, summary)
      expanded = fetch(store, weapon.wiki_en) or return nil
      found = parse(expanded.body).filter_map do |option|
        key = keys_by_name[option[:key_name].downcase]
        next(summary.unmatched << "#{weapon.name_en}: #{option[:key_name]}") && nil unless key

        [key, option[:versions]]
      end
      return nil if found.empty?

      ActiveRecord::Base.transaction(requires_new: true) { write(weapon, found) }
      found.size
    end

    def summary_line(summary)
      line = "Weapon key skills: #{summary.keys} keys on #{summary.weapons} weapons"
      line += "; unmatched: #{summary.unmatched.uniq.join(', ')}" if summary.unmatched.any?
      line += "; #{summary.failed.size} weapons failed and kept their rows" if summary.failed.any?
      line
    end

    def keyed_weapons
      Weapon.joins(:weapon_series).where(weapon_series: { has_weapon_keys: true }).where.not(wiki_en: [nil, ''])
    end

    def fetch(store, key)
      store.fetch('expanded', key)
    rescue SourceStore::SourceMissing
      nil
    end

    def write(weapon, found)
      existing = WeaponKeySkill.where(weapon_granblue_id: weapon.granblue_id).index_by(&:weapon_key_id)
      found.each do |key, versions|
        versions = versions.map(&:stringify_keys)
        row = existing.delete(key.id) || WeaponKeySkill.new(weapon_granblue_id: weapon.granblue_id, weapon_key: key)
        row.versions = versions
        row.save! if row.changed?
      end
      WeaponKeySkill.where(id: existing.values.map(&:id)).delete_all if existing.any?
    end
  end
end
