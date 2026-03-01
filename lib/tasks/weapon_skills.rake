# frozen_string_literal: true

namespace :granblue do
  desc <<~DESC
    Parse weapon skills from wiki_raw into Skill + WeaponSkill records.

    Usage:
      rake granblue:parse_weapon_skills           # Parse weapons missing skills
      rake granblue:parse_weapon_skills force=true # Re-parse all weapons
  DESC
  task parse_weapon_skills: :environment do
    overwrite = ENV['force'] == 'true'

    result = Granblue::Parsers::WeaponParser.persist_all_skills(
      debug: true, overwrite: overwrite
    )

    # Find weapons that have wiki_raw but still have 0 skills
    no_skills = Weapon.where.not(wiki_raw: [nil, ''])
                      .left_joins(:weapon_skills)
                      .where(weapon_skills: { id: nil })
                      .pluck(:granblue_id, :name_en, :wiki_en)
                      .map { |gid, name, wiki| { granblue_id: gid, name_en: name, wiki_en: wiki } }

    report = {
      processed: result[:processed],
      skipped: result[:skipped],
      errors: result[:errors],
      no_skills_count: no_skills.size,
      no_skills: no_skills
    }

    report_path = Rails.root.join('tmp', 'weapon_skill_parse_report.json')
    FileUtils.mkdir_p(File.dirname(report_path))
    File.write(report_path, JSON.pretty_generate(report))

    puts
    puts "=== Summary ==="
    puts "Processed: #{result[:processed]}"
    puts "Skipped: #{result[:skipped]}"
    puts "Errors: #{result[:errors].size}"
    puts "No skills after parse: #{no_skills.size}"
    puts "Report: #{report_path}"
  end

  desc <<~DESC
    Dry-run report on weapon skill parsing quality (does not persist).

    Usage:
      rake granblue:weapon_skill_report
  DESC
  task weapon_skill_report: :environment do
    weapons = Weapon.where.not(wiki_raw: [nil, ''])
    total = weapons.count
    puts "Inspecting #{total} weapons with wiki_raw..."

    no_skills = []
    unparseable = []
    ok_count = 0

    weapons.find_each.with_index do |weapon, i|
      if (i + 1) % 100 == 0
        puts "  #{i + 1}/#{total}..."
      end

      parser = Granblue::Parsers::WeaponParser.new(granblue_id: weapon.granblue_id)
      extracted = parser.send(:parse_string, weapon.wiki_raw)

      skill_data = parser.send(:extract_weapon_skills, extracted)

      if skill_data.empty?
        no_skills << {
          granblue_id: weapon.granblue_id,
          name_en: weapon.name_en,
          wiki_en: weapon.wiki_en
        }
        next
      end

      # Check for skills with unparseable names (nil modifier/series/size)
      bad_skills = []
      skill_data.each do |slot|
        [slot[:base], slot[:upgrade]].compact.each do |entry|
          if entry[:modifier].nil? || entry[:series].nil?
            bad_skills << {
              name: entry[:name_en],
              modifier: entry[:modifier],
              series: entry[:series],
              size: entry[:size]
            }
          end
        end
      end

      if bad_skills.any?
        unparseable << {
          granblue_id: weapon.granblue_id,
          name_en: weapon.name_en,
          wiki_en: weapon.wiki_en,
          skills: bad_skills
        }
      else
        ok_count += 1
      end
    rescue StandardError => e
      unparseable << {
        granblue_id: weapon.granblue_id,
        name_en: weapon.name_en,
        wiki_en: weapon.wiki_en,
        error: e.message
      }
    end

    report = {
      total: total,
      ok: ok_count,
      no_skills: no_skills,
      no_skills_count: no_skills.size,
      unparseable: unparseable,
      unparseable_count: unparseable.size
    }

    report_path = Rails.root.join('tmp', 'weapon_skill_report.json')
    FileUtils.mkdir_p(File.dirname(report_path))
    File.write(report_path, JSON.pretty_generate(report))

    puts
    puts "=== Report ==="
    puts "Total with wiki_raw: #{total}"
    puts "OK (skills parsed cleanly): #{ok_count}"
    puts "No skills extracted: #{no_skills.size}"
    puts "Unparseable skills: #{unparseable.size}"
    puts "Details: #{report_path}"
  end
end
