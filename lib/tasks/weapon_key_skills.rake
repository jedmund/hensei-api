# frozen_string_literal: true

namespace :granblue do
  desc "Compatibility alias for loading key effects from the canonical weapon-skill effect snapshot"
  task load_weapon_key_skills: :environment do
    warn "granblue:load_weapon_key_skills is deprecated; loading data/weapon_skill_effects.json instead."
    Rake::Task["granblue:load_weapon_skill_effects"].invoke
  end
end
