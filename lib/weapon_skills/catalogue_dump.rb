# frozen_string_literal: true

require "open3"

module WeaponSkills
  # A data-only dump of the game catalogue (no users, parties, grids, collections, crews
  # or OAuth), so any agent or environment can restore the same weapon-skill domain
  # without a production backup. Published as a draft GitHub release asset
  # (catalogue-YYYYMMDD on jedmund/hensei-api) and restored by bin/setup-pipeline-db.
  module CatalogueDump
    REPO = "jedmund/hensei-api"
    ASSET = "catalogue.dump"
    TAG_METADATA_KEY = "catalogue_tag"

    # Every table here must be public game data. spec/lib/weapon_skills/catalogue_dump_spec.rb
    # fails if one gains a column that looks like user data.
    TABLES = %w[
      weapons weapon_series weapon_series_variants weapon_awakenings awakenings weapon_stat_modifiers
      weapon_keys weapon_key_series
      skills weapon_skills weapon_skill_versions weapon_skill_data weapon_skill_effects
      weapon_skill_families weapon_skill_boost_types panel_lines sources
      summons summon_series summon_auras summon_calls
      characters character_series character_series_memberships character_skills character_skill_versions
      character_skill_version_links skill_effects skill_values charge_attacks
      jobs job_skills job_accessories raids raid_groups bullets
      arcarum_blessings arcarum_blessing_levels effects statuses data_versions
      data_migrations
    ].freeze

    USER_DATA_COLUMN = /\A(user_id|email|username|password|edit_key|token|crew_id|party_id)\z/

    module_function

    def tag_for(date = Date.current) = "catalogue-#{date.strftime('%Y%m%d')}"

    def pg_dump_command(database_url, path)
      ["pg_dump", "-Fc", "-Z9", "--data-only", "--no-owner", "--no-privileges",
       *TABLES.flat_map { |t| ["-t", t] }, "-f", path.to_s, database_url]
    end

    # Whether REPO already has a release (draft or published) with this tag. Listed rather
    # than looked up by git tag: a draft has no git tag, and GitHub lets two drafts share
    # one (catalogue-20261015 was published twice).
    def release_exists?(tag, runner: Open3)
      out, status = runner.capture2("gh", "release", "list", "--repo", REPO, "--limit", "1000",
                                    "--json", "tagName", "--jq", ".[].tagName")
      raise "gh release list failed (exit #{status.exitstatus})" unless status.success?

      out.split("\n").map(&:strip).include?(tag)
    end

    # The tag recorded by bin/setup-pipeline-db, if this database was restored from a dump.
    def restored_tag
      ActiveRecord::Base.connection.select_value(
        ActiveRecord::Base.sanitize_sql(["SELECT value FROM ar_internal_metadata WHERE key = ?", TAG_METADATA_KEY])
      )
    rescue ActiveRecord::StatementInvalid
      nil
    end
  end
end
