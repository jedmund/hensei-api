# frozen_string_literal: true

module WeaponSkills
  # Builds one weapon's skills after its page is stored or changes (Weapon#enqueue_skill_build),
  # so a new weapon doesn't wait for the next deploy.
  #
  # First it fetches the pages the build follows from its page (expanded, transclusion; a few
  # throttled gbf.wiki requests), keeping the page itself as stored: a series-template page needs
  # its expansion, which an editor's import doesn't store. A failed fetch is logged and the build
  # goes on from what's stored.
  #
  # Writes when the weapon has no skills yet, or when WEAPON_SKILL_BUILD is write; otherwise
  # builds in shadow and logs what would change. Never overlaps another weapon build
  # (BuildLock): when one is running, it re-queues itself a minute later.
  class BuildJob < ApplicationJob
    queue_as :default

    discard_on ActiveRecord::RecordNotFound

    RETRY_WAIT = 1.minute
    FOLLOWED_KINDS = %w[expanded transclusion].freeze

    def perform(weapon_id)
      weapon = Weapon.find(weapon_id)
      fetch_followed_pages(weapon)
      build(weapon)
    rescue BuildLock::Busy
      Rails.logger.info "[WEAPON_SKILLS] #{weapon_id}: another build is running; re-queued"
      self.class.set(wait: RETRY_WAIT).perform_later(weapon_id)
      nil
    end

    def self.mode_for(weapon)
      return "write" if WeaponSkills.build_mode == "write"

      WeaponSkill.exists?(weapon_granblue_id: weapon.granblue_id) ? "shadow" : "write"
    end

    private

    def fetch_followed_pages(weapon)
      fetcher = SourceStore::Fetcher.new(delay: Granblue::WikiThrottle::MIN_DELAY)
      # Its writes don't change the weapon's page, but must not queue this job again either way.
      Weapon.without_skill_build { fetcher.fetch_weapon(weapon, kinds: FOLLOWED_KINDS) }
      fetcher.failures.each do |failure|
        Rails.logger.warn "[WEAPON_SKILLS] #{weapon.granblue_id}: #{failure[:kind]} #{failure[:key]}: #{failure[:error]}"
      end
    rescue StandardError => e
      Rails.logger.warn "[WEAPON_SKILLS] #{weapon.granblue_id}: fetch failed, building from stored pages: " \
                        "#{e.class}: #{e.message}"
    end

    def build(weapon)
      mode = self.class.mode_for(weapon)
      log = StringIO.new
      summary = Build::Runner.new(mode: mode, ids: [weapon.granblue_id], io: log, lock_wait: 0).call
      Rails.logger.info "[WEAPON_SKILLS] #{weapon.granblue_id} (#{mode}): #{log.string.strip.lines.last&.strip}"
      log.string.lines.each { |line| Rails.logger.info "[WEAPON_SKILLS]   #{line.strip}" } if mode == "shadow"
      summary
    end
  end
end
