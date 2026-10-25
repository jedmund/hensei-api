# frozen_string_literal: true

require 'json'

module Granblue
  # Renames the bucket images whose file names carry an element or proficiency number,
  # after data migration 20261024120000 moved those numbers to the game's:
  #
  #   icons/mastery/ele-{element}.png
  #   weapons/keys/gauph-*-{proficiency}.png
  #   weapons/{size}/{granblue_id}_{element}.{ext}          element-changeable weapons
  #   characters/{size}/{id}_{pose}_0{element}[_{gender}]    null-element characters
  #   icons/weapon-skills/{lang}/{stem}.png                  element-wildcard skill icons
  #
  # The new names are a permutation of the old ones, so files can't be renamed in place.
  # `stage` copies every old file to its new name under STAGE_PREFIX, `apply` copies the
  # staged files over the new names, and `cleanup` deletes the staged copies. Nothing else
  # is deleted, and the plan is saved by `plan` so `apply` never recomputes it from a
  # half-renamed bucket. The bucket has no versioning: keep the staged copies until the
  # site has been checked.
  class EnumImageRenumbering
    MIGRATION_VERSION = '20261024120000'
    STAGE_PREFIX = 'tmp/renumber-enums/'
    PLAN_PATH = Rails.root.join('tmp/renumber_enum_images_plan.json')

    # old number => new number, as in the data migration
    ELEMENT = { 1 => 4, 2 => 1, 3 => 2, 4 => 3, 5 => 6, 6 => 5 }.freeze
    PROFICIENCY = { 3 => 4, 4 => 3, 5 => 8, 6 => 5, 8 => 9, 9 => 6 }.freeze
    OLD_ELEMENT = ELEMENT.invert.freeze

    SKILL_ICON_LANGS = %w[en ja].freeze
    GAUPH_SLUGS = %w[gauph-courage gauph-strength gauph-strife gauph-vitality gauph-will gauph-zeal].freeze
    WEAPON_VARIANT = %r{\Aweapons/(?<size>[^/]+)/(?<id>\d+)_(?<element>[1-6])\.(?<ext>jpg|png)\z}
    CHARACTER_VARIANT = %r{\Acharacters/(?<size>[^/]+)/(?<base>\d+_\d{2})_0(?<element>[1-6])(?<gender>_[01])?\.(?<ext>jpg|png)\z}

    def initialize(aws: AwsService.new, out: $stdout)
      @s3 = aws.s3_client
      @bucket = aws.bucket
      @out = out
    end

    # Builds the rename list from the bucket and the (already migrated) database and saves it.
    def plan
      unless ActiveRecord::Base.connection.select_value("SELECT 1 FROM data_migrations WHERE version = '#{MIGRATION_VERSION}'")
        raise "Run data migration #{MIGRATION_VERSION} first: skill icon names are read from migrated weapon elements"
      end

      keys = list('icons/mastery/') + list('weapons/') + list('characters/') + list('icons/weapon-skills/')
      existing = keys.to_set
      renames = candidate_renames(keys).select { |old, new| old != new && existing.include?(old) }.uniq.sort
      File.write(PLAN_PATH, JSON.pretty_generate(renames.map { |old, new| { old: old, new: new } }))
      report(renames)
      renames
    end

    def stage
      each_planned('stage') { |old, new| copy(old, "#{STAGE_PREFIX}#{new}") }
    end

    def apply
      missing = saved_plan.reject { |r| exists?("#{STAGE_PREFIX}#{r['new']}") }
      raise "#{missing.size} staged files are missing, run stage again: #{missing.first(5).inspect}" if missing.any?

      each_planned('apply') { |_old, new| copy("#{STAGE_PREFIX}#{new}", new) }
    end

    def cleanup
      each_planned('cleanup') { |_old, new| @s3.delete_object(bucket: @bucket, key: "#{STAGE_PREFIX}#{new}") }
    end

    private

    def candidate_renames(keys)
      renames = ELEMENT.map { |old, new| ["icons/mastery/ele-#{old}.png", "icons/mastery/ele-#{new}.png"] }
      GAUPH_SLUGS.each do |slug|
        PROFICIENCY.each { |old, new| renames << ["weapons/keys/#{slug}-#{old}.png", "weapons/keys/#{slug}-#{new}.png"] }
      end

      keys.each do |key|
        if (m = WEAPON_VARIANT.match(key))
          renames << [key, "weapons/#{m[:size]}/#{m[:id]}_#{ELEMENT[m[:element].to_i]}.#{m[:ext]}"]
        elsif (m = CHARACTER_VARIANT.match(key))
          renames << [key, "characters/#{m[:size]}/#{m[:base]}_0#{ELEMENT[m[:element].to_i]}#{m[:gender]}.#{m[:ext]}"]
        end
      end

      renames + skill_icon_renames
    end

    # Element-wildcard icons: the stored name used the weapon's old element number.
    def skill_icon_renames
      WeaponSkillVersion.includes(weapon_skill: :weapon).where.not(icon: [nil, '']).find_each.flat_map do |version|
        template = version.icon_template
        new_stem = version.icon_stem
        next [] unless template&.include?('*') && new_stem

        old_stem = template.gsub('*', OLD_ELEMENT.fetch(version.weapon_skill.weapon.element).to_s)
        SKILL_ICON_LANGS.map { |lang| ["icons/weapon-skills/#{lang}/#{old_stem}.png", "icons/weapon-skills/#{lang}/#{new_stem}.png"] }
      end
    end

    def report(renames)
      groups = renames.group_by { |old, _| old.split('/').first(2).join('/') }
      groups.sort.each { |prefix, rows| @out.puts "#{prefix}: #{rows.size}" }
      @out.puts "#{renames.size} renames planned (saved to #{PLAN_PATH})"
    end

    def saved_plan
      raise "No plan at #{PLAN_PATH}; run step=plan first" unless File.exist?(PLAN_PATH)

      JSON.parse(File.read(PLAN_PATH))
    end

    def each_planned(step)
      plan = saved_plan
      plan.each_with_index do |row, i|
        yield row['old'], row['new']
        @out.puts "  #{step}: #{i + 1}/#{plan.size}" if ((i + 1) % 200).zero?
      end
      @out.puts "#{step}: #{plan.size} done"
    end

    def copy(from, to)
      @s3.copy_object(bucket: @bucket, key: to, copy_source: "#{@bucket}/#{ERB::Util.url_encode(from).gsub('%2F', '/')}")
    end

    def exists?(key)
      @s3.head_object(bucket: @bucket, key: key)
      true
    rescue Aws::S3::Errors::NotFound
      false
    end

    def list(prefix)
      keys = []
      @s3.list_objects_v2(bucket: @bucket, prefix: prefix).each_page { |page| keys.concat(page.contents.map(&:key)) }
      keys
    end
  end
end
