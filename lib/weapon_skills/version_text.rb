# frozen_string_literal: true

module WeaponSkills
  # The one accessor for a skill version's text: the version's own tier text, else the
  # shared Skill catalogue's (the name/icon holder, whose text several weapons and tiers
  # overwrite). Readers go through here, never through Skill#description_* directly.
  module VersionText
    LOCALES = { en: :description_en, jp: :description_jp, ja: :description_jp }.freeze

    module_function

    # locale: :en, or :jp / :ja
    def for(version, locale)
      column = LOCALES.fetch(locale.to_sym) { raise ArgumentError, "unknown locale #{locale.inspect}" }
      return nil unless version

      version.read_attribute(column).presence || version.skill&.public_send(column)
    end
  end
end
