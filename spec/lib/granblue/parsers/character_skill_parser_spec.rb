# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Granblue::Parsers::CharacterSkillParser do
  describe '#parse' do
    context 'with Vikala' do
      it 'parses enhanced, transform-alt, ougi-upgrade, and support versions' do
        character, report = parse_sample(:vikala)
        skills = character.character_skills.includes(:character_skill_versions).to_a

        slot1 = slot(skills, :ability, 1)
        slot2 = slot(skills, :ability, 2)
        ougi = slot(skills, :ougi, 1)

        aggregate_failures do
          expect(unmatched_statuses(report)).to be_empty
          expect(skills.count { |skill| skill.kind == 'ability' }).to eq(4)
          expect(skills.count { |skill| skill.kind == 'support' }).to eq(2)
          expect(roles(slot1)).to include('base', 'enhanced')
          expect(version_named(slot2, 'Dazzling Dreams').variant_role).to eq('base')
          expect(version_named(slot2, 'Eccentric Parade').variant_role).to eq('transform_alt')
          expect(version_named(slot2, 'Eccentric Parade').trigger_type).to eq('field_effect')
          expect(version_named(slot2, 'Eccentric Parade').trigger_value).to include('Utopia')
          expect(link_relations(slot2)).to include('transforms_to')
          expect(roles(ougi)).to include('base', 'uncap_upgrade')
          expect(version_named(ougi, 'Pandemousium').min_uncap).to eq(5)
        end
      end
    end

    context 'with Caim' do
      it 'parses conditional trick transforms and option menu links' do
        character, report = parse_sample(:caim)
        skills = character.character_skills.includes(:character_skill_versions).to_a

        blank_face = slot(skills, :ability, 3)
        secret_hands = slot(skills, :ability, 4)
        ougi = slot(skills, :ougi, 1)

        aggregate_failures do
          expect(unmatched_statuses(report)).to be_empty
          expect(skills.count { |skill| skill.kind == 'ability' }).to eq(4)
          expect(skills.count { |skill| skill.kind == 'support' }).to eq(4)
          expect(version_named(blank_face, 'Blank Face').variant_role).to eq('conditional')
          expect(versions(blank_face).count { |version| version.variant_role == 'transform_alt' }).to eq(4)
          expect(versions(blank_face).select { |version| version.variant_role == 'transform_alt' }).to all(be_mimicable)
          expect(link_relations(blank_face).count('transforms_to')).to eq(4)
          expect(version_named(secret_hands, 'Secret Hands').variant_role).to eq('base')
          expect(versions(secret_hands).count { |version| version.variant_role == 'option' }).to eq(4)
          expect(link_relations(secret_hands).count('option_of')).to eq(4)
          expect(roles(ougi)).to include('base', 'uncap_upgrade')
        end
      end
    end

    context 'with Threo' do
      it 'parses form counterparts, transcendence upgrades, and all ougi forms' do
        character, report = parse_sample(:threo)
        skills = character.character_skills.includes(:character_skill_versions).to_a
        ability_slots = skills.select { |skill| skill.kind == 'ability' }
        ougi = slot(skills, :ougi, 1)

        aggregate_failures do
          expect(unmatched_statuses(report)).to be_empty
          expect(ability_slots.size).to eq(4)
          expect(skills.count { |skill| skill.kind == 'support' }).to eq(3)
          expect(ability_slots).to all(have_form_alt_counterpart)
          expect(ability_slots.flat_map { |skill| roles(skill) }).to include('enhanced', 'transcendence_upgrade')
          expect(link_relations_for(ability_slots).count('form_counterpart')).to be >= 4
          expect(versions(ougi).size).to eq(8)
          expect(roles(ougi)).to include('base', 'uncap_upgrade', 'transcendence_upgrade')
        end
      end
    end

    context 'with Wamdus' do
      it 'parses Ravenous Drain options and auto-activation' do
        character, report = parse_sample(:wamdus)
        skills = character.character_skills.includes(:character_skill_versions).to_a

        ravenous_drain = slot(skills, :ability, 1)
        innocence_toxin = slot(skills, :ability, 2)

        aggregate_failures do
          expect(unmatched_statuses(report)).to be_empty
          expect(skills.count { |skill| skill.kind == 'ability' }).to eq(3)
          expect(skills.count { |skill| skill.kind == 'support' }).to eq(2)
          expect(versions(ravenous_drain).count { |version| version.variant_role == 'option' }).to eq(2)
          expect(link_relations(ravenous_drain).count('option_of')).to eq(2)
          expect(versions(innocence_toxin)).to include(be_auto_activate)
          expect(skills.flat_map { |skill| versions(skill) }.filter_map(&:min_uncap)).to all(be <= 4)
        end
      end
    end

    context 'with Orologia' do
      it 'parses composed stack-gated transform and option set' do
        character, report = parse_sample(:orologia)
        skills = character.character_skills.includes(:character_skill_versions).to_a

        causa_temporis = slot(skills, :ability, 3)
        victoriae_calculus = version_named(causa_temporis, 'Victoriae Calculus')

        aggregate_failures do
          expect(unmatched_statuses(report)).to be_empty
          expect(skills.count { |skill| skill.kind == 'ability' }).to eq(3)
          expect(skills.count { |skill| skill.kind == 'support' }).to eq(3)
          expect(version_named(causa_temporis, 'Causa Temporis').variant_role).to eq('base')
          expect(victoriae_calculus.variant_role).to eq('transform_alt')
          expect(victoriae_calculus.trigger_type).to eq('stack_threshold')
          expect(victoriae_calculus.trigger_value).to include('Causal Intervention')
          expect(victoriae_calculus.trigger_value).to include('4')
          expect(versions(causa_temporis).count { |version| version.variant_role == 'option' }).to eq(3)
          expect(link_relations(causa_temporis)).to include('transforms_to')
          expect(link_relations(causa_temporis).count('option_of')).to eq(3)
        end
      end
    end
  end

  # Builds each sample character, populates the Status catalog through the real
  # production builder, then parses — so "0 unmatched statuses" exercises the same
  # catalog path as the rake tasks rather than a test-only seed.
  context 'with cached Japanese wiki data' do
    it 'aligns JP names and descriptions onto the EN graph by position (Vikala)' do
      character, = parse_sample(:vikala)
      slot2 = character.character_skills.find_by(kind: 'ability', position: 2)
      versions = slot2.character_skill_versions

      aggregate_failures do
        expect(versions.find_by(variant_role: 'base').name_jp).to eq('エンチャンテッド・ドリーム')
        expect(versions.find_by(variant_role: 'transform_alt').name_jp).to eq('エキセントリックパレード')
        expect(versions.find_by(variant_role: 'base').description_jp).to be_present
        expect(slot2.character_skill_versions.where(variant_role: 'enhanced').first&.name_jp)
          .to eq('エンチャンテッド・ドリーム')
      end
    end
  end

  def parse_sample(key)
    sample = samples.fetch(key)
    jp_path = fixture_dir.join("character-#{key}-jpwiki.html")
    character = create(
      :character,
      granblue_id: sample.fetch(:granblue_id),
      name_en: sample.fetch(:name),
      wiki_raw: File.read(fixture_dir.join(sample.fetch(:wiki))),
      game_raw_en: JSON.parse(File.read(fixture_dir.join(sample.fetch(:game)))),
      game_raw_jp: nil,
      wiki_raw_jp: (File.read(jp_path) if File.exist?(jp_path))
    )

    Granblue::Parsers::StatusCatalogBuilder.build_all

    report = described_class.new(character).parse(persist: true)
    [character.reload, report]
  end

  def fixture_dir
    Rails.root.join('spec/fixtures/character_skills')
  end

  def samples
    {
      vikala: {
        granblue_id: '3040252000',
        name: 'Vikala',
        game: 'character-vikala-gamedata.json',
        wiki: 'character-vikala-wikidata.txt'
      },
      caim: {
        granblue_id: '3040164000',
        name: 'Caim',
        game: 'character-caim-gamedata.json',
        wiki: 'character-caim-wikidata.txt'
      },
      threo: {
        granblue_id: '3040032000',
        name: 'Threo',
        game: 'character-threo-gamedata.json',
        wiki: 'character-threo-wikidata.txt'
      },
      wamdus: {
        granblue_id: '3040419000',
        name: 'Wamdus',
        game: 'character-wamdus-gamedata.json',
        wiki: 'character-wamdus-wikidata.txt'
      },
      orologia: {
        granblue_id: '3040536000',
        name: 'Orologia',
        game: 'character-orologia-gamedata.json',
        wiki: 'character-orologia-wikidata.txt'
      }
    }
  end

  def unmatched_statuses(report)
    report[:unmatched_statuses] || []
  end

  def slot(skills, kind, position)
    skills.find { |skill| skill.kind == kind.to_s && skill.position == position }.tap do |skill|
      expect(skill).to be_present
    end
  end

  def versions(skill)
    skill.character_skill_versions.to_a
  end

  def roles(skill)
    versions(skill).map(&:variant_role)
  end

  def version_named(skill, name)
    versions(skill).find { |version| version.name_en.include?(name) }.tap do |version|
      expect(version).to be_present
    end
  end

  def link_relations(skill)
    link_relations_for([skill])
  end

  def link_relations_for(skills)
    CharacterSkillVersionLink
      .where(from_version_id: skills.flat_map { |skill| versions(skill).map(&:id) })
      .pluck(:relation)
  end

  def have_form_alt_counterpart
    satisfy('have a form_alt version and form_counterpart link') do |skill|
      roles(skill).include?('form_alt') && link_relations(skill).include?('form_counterpart')
    end
  end
end
