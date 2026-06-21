# frozen_string_literal: true

namespace :granblue do
  desc "Auto-generate element-agnostic key→skill effects from the weapon-series summary pages. DRY_RUN=1 to preview."
  task extract_key_skills: :environment do
    stats, preview = Granblue::Extractors::KeySkillExtractor.run(dry_run: ENV["DRY_RUN"].present?)
    preview.each { |p| puts "  #{p[:slug].ljust(24)} #{p[:effects].join(', ')}" } if ENV["DRY_RUN"].present?
    puts "Key skill extraction: #{stats.sort_by { |k, _| k.to_s }.to_h.inspect}"
  end
end
