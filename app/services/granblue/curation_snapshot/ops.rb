# frozen_string_literal: true

module Granblue
  class CurationSnapshot
    # Structural curation ops (docs/weapon-skill-pipeline/overlay-v2.md): remove_version,
    # add_version, gate and description. Each op is idempotent; #apply returns
    #   :applied    it changed the database;
    #   :satisfied  the database already matched;
    #   :skipped    it can't apply here yet (a description op before the text columns exist);
    #   :unmatched  it names a version or weapon this database doesn't have.
    class Ops
      GATE_FIELDS = WeaponSkills::OverlaySchema::GATE_FIELDS
      DESCRIPTION_FIELDS = %w[description_en description_jp].freeze

      # The per-version text columns arrive with W6c; until then description ops wait.
      # Read fresh: the deploy sync runs in the process that just migrated.
      def self.description_columns?
        WeaponSkillVersion.reset_column_information
        DESCRIPTION_FIELDS.all? { |column| WeaponSkillVersion.column_names.include?(column) }
      end

      def initialize
        @description_columns = self.class.description_columns?
      end

      def apply(entry)
        case entry["op"]
        when "remove_version" then remove_version(entry)
        when "add_version" then add_version(entry)
        when "gate" then set_fields(entry, gate_attrs(entry))
        when "description" then description(entry)
        else raise ArgumentError, "unknown curation op #{entry['op']}"
        end
      end

      # Whether the database already reflects the op (the drift check's "unapplied").
      def satisfied?(entry)
        version = CurationSnapshot.find_version(entry)
        case entry["op"]
        when "remove_version" then version.nil?
        when "add_version" then !version.nil?
        when "gate" then !version.nil? && matches?(version, gate_attrs(entry))
        when "description"
          !@description_columns || (!version.nil? && matches?(version, entry.slice(*DESCRIPTION_FIELDS)))
        end
      end

      private

      def remove_version(entry)
        version = CurationSnapshot.find_version(entry)
        return WeaponSkill.exists?(weapon_granblue_id: entry["weapon"]) ? :satisfied : :unmatched unless version

        slot = version.weapon_skill
        WeaponSkillEffect.where(weapon_skill_version_id: version.id).delete_all
        WeaponSkillDatum.where(weapon_skill_version_id: version.id).delete_all
        version.destroy!
        slot.destroy! unless slot.weapon_skill_versions.exists?
        :applied
      end

      def add_version(entry)
        return :satisfied if CurationSnapshot.find_version(entry)
        return :unmatched unless Weapon.exists?(granblue_id: entry["weapon"])

        slot = WeaponSkill.find_by(weapon_granblue_id: entry["weapon"], position: entry["position"])
        return :unmatched if slot&.weapon_skill_versions&.exists?(ordinal: entry["ordinal"]) # another skill holds that tier

        slot ||= WeaponSkill.create!(weapon_granblue_id: entry["weapon"], position: entry["position"])
        WeaponSkillVersion.create!(new_version_attrs(entry).merge(weapon_skill: slot, skill: skill_for(entry)))
        :applied
      end

      def new_version_attrs(entry)
        attrs = { ordinal: entry["ordinal"], unlock_level: entry["unlock_level"], min_uncap: entry["min_uncap"],
                  transcendence_stage: entry["transcendence_stage"] || 0 }.merge(classification(entry))
        attrs.merge!(entry.slice(*DESCRIPTION_FIELDS).symbolize_keys) if @description_columns
        attrs
      end

      # The derived classification the importers give a new version; the overlay's
      # version overrides correct it like any other.
      def classification(entry)
        parsed = Granblue::Parsers::WeaponSkillParser.parse(entry["skill"])
        modifier = parsed[:modifier]&.sub(/:\s*(Fire|Water|Earth|Wind|Light|Dark)\z/, "")
        modifier = nil unless WeaponSkillVersion::VALID_MODIFIERS.include?(modifier)
        series = Granblue::Parsers::WeaponSkillDescriptionParser.series_for(entry["description_en"], entry["skill"])
        { skill_modifier: modifier, skill_series: series.presence, skill_size: parsed[:size].presence }
      end

      # Skills are shared by name; a new name gets the op's Japanese name and text.
      def skill_for(entry)
        skill = Skill.find_or_initialize_by(name_en: entry["skill"], skill_type: :weapon)
        return skill if skill.persisted?

        skill.update!(name_jp: entry["skill_jp"], description_en: entry["description_en"], description_jp: entry["description_jp"])
        skill
      end

      def description(entry)
        return :skipped unless @description_columns

        set_fields(entry, entry.slice(*DESCRIPTION_FIELDS))
      end

      def gate_attrs(entry)
        attrs = entry.slice(*GATE_FIELDS)
        attrs["transcendence_stage"] ||= 0 if attrs.key?("transcendence_stage") # the column is not null
        attrs
      end

      def set_fields(entry, attrs)
        version = CurationSnapshot.find_version(entry) or return :unmatched
        return :satisfied if matches?(version, attrs)

        # update_columns: the version model delegates description_* to its skill.
        version.update_columns(attrs.merge("updated_at" => Time.current))
        :applied
      end

      def matches?(version, attrs)
        attrs.all? { |column, value| version.read_attribute(column) == value }
      end
    end
  end
end
