# frozen_string_literal: true

require 'rails_helper'

# Characterization (golden-snapshot) test. Locks the exact observable parse output
# — slots, versions, effects (with resolved status names), and links — for the
# sample characters, so the parser can be refactored (e.g. the #5 builder split)
# with proof that behavior is unchanged. Regenerate goldens with REGENERATE=1.
RSpec.describe 'CharacterSkillParser golden snapshots' do
  samples = {
    vikala: { granblue_id: '3040252000', name: 'Vikala' },
    caim: { granblue_id: '3040164000', name: 'Caim' },
    threo: { granblue_id: '3040032000', name: 'Threo' },
    wamdus: { granblue_id: '3040419000', name: 'Wamdus' },
    orologia: { granblue_id: '3040536000', name: 'Orologia' }
  }

  samples.each do |key, sample|
    it "matches the golden snapshot for #{sample[:name]}" do
      snapshot = parse_snapshot(key, sample)
      golden = golden_dir.join("#{key}.json")

      if ENV['REGENERATE'] == '1' || !golden.exist?
        golden.write("#{JSON.pretty_generate(snapshot)}\n")
        skip "regenerated golden for #{key}"
      else
        expect(snapshot).to eq(JSON.parse(golden.read))
      end
    end
  end

  def fixture_dir
    Rails.root.join('spec/fixtures/character_skills')
  end

  def golden_dir
    fixture_dir.join('golden').tap(&:mkpath)
  end

  def parse_snapshot(key, sample)
    jp = fixture_dir.join("character-#{key}-jpwiki.html")
    character = create(
      :character,
      granblue_id: sample[:granblue_id], name_en: sample[:name],
      wiki_raw: File.read(fixture_dir.join("character-#{key}-wikidata.txt")),
      game_raw_en: JSON.parse(File.read(fixture_dir.join("character-#{key}-gamedata.json"))),
      game_raw_jp: nil,
      wiki_raw_jp: (File.read(jp) if File.exist?(jp))
    )
    Granblue::Parsers::StatusCatalogBuilder.build_all
    @lookup = Granblue::Parsers::CharacterSkillParser.build_status_lookup
    normalize(Granblue::Parsers::CharacterSkillParser.new(character).parse)
  end

  def normalize(report)
    labels = {}
    report[:slots].each do |slot|
      slot[:versions].each { |v| labels[v[:key]] = "#{slot[:attrs][:kind]}#{slot[:attrs][:position]}:#{v[:attrs][:name_en]}" }
    end
    {
      'slots' => report[:slots].map { |slot| normalize_slot(slot) },
      'links' => report[:links].map { |link| [labels[link[:from_version_key]], link[:relation], labels[link[:to_version_key]]] }
    }
  end

  def normalize_slot(slot)
    { 'kind' => slot[:attrs][:kind], 'position' => slot[:attrs][:position],
      'versions' => slot[:versions].map { |version| normalize_version(version) } }
  end

  def normalize_version(version)
    attrs = version[:attrs]
    {
      'name_en' => attrs[:name_en], 'name_jp' => attrs[:name_jp],
      'description_en' => attrs[:description_en], 'description_jp' => attrs[:description_jp],
      'variant_role' => attrs[:variant_role], 'ordinal' => attrs[:ordinal], 'type_color' => attrs[:type_color],
      'cooldown' => attrs[:cooldown], 'initial_cooldown' => attrs[:initial_cooldown],
      'duration' => [attrs[:duration_value], attrs[:duration_unit]],
      'unlock_level' => attrs[:unlock_level], 'enhance_levels' => attrs[:enhance_levels],
      'min_uncap' => attrs[:min_uncap], 'transcendence_stage' => attrs[:transcendence_stage],
      'trigger' => [attrs[:trigger_type], attrs[:trigger_value]],
      'flags' => %i[cant_recast one_time_use auto_activate mimicable targets_all].select { |f| attrs[f] }.map(&:to_s),
      'effects' => version[:effects].map { |effect| normalize_effect(effect) }
    }
  end

  def normalize_effect(effect)
    {
      'type' => effect[:effect_type], 'target' => effect[:target],
      'status' => (@lookup[:by_id][effect[:status_id]]&.name_en if effect[:status_id]),
      'amount' => effect[:amount], 'amount_max' => effect[:amount_max],
      'duration' => [effect[:duration_value], effect[:duration_unit]],
      'accuracy' => effect[:accuracy], 'stacking_frame' => effect[:stacking_frame],
      'damage_pct' => effect[:damage_pct]&.to_s, 'hit_count' => effect[:hit_count], 'damage_cap' => effect[:damage_cap]
    }
  end
end
