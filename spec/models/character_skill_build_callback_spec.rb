# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Character, 'skill build callback' do
  include ActiveJob::TestHelper

  it 'queues one build when a character is created with wiki_raw' do
    expect { create(:character, wiki_raw: '{{Character}}') }.to have_enqueued_job(CharacterSkills::BuildJob).exactly(:once)
  end

  it 'queues none for a new character with nothing to build from' do
    expect { create(:character, wiki_raw: nil) }.not_to have_enqueued_job(CharacterSkills::BuildJob)
  end

  context 'with an existing character' do
    let!(:character) { described_class.without_skill_build { create(:character, wiki_raw: '{{Character}}', element: 2) } }

    it 'queues none when name_en changes' do
      expect { character.update!(name_en: 'Renamed') }.not_to have_enqueued_job(CharacterSkills::BuildJob)
    end

    {
      'wiki_raw' => '{{Character|x=1}}', 'wiki_raw_jp' => '<p>x</p>', 'game_raw_en' => { 'style' => 1 },
      'game_raw_jp' => { 'style' => 1 }, 'element' => 3, 'style_swap' => true, 'granblue_id' => '3040999999'
    }.each do |column, value|
      it "queues a build when #{column} changes" do
        expect { character.update!(column => value) }
          .to have_enqueued_job(CharacterSkills::BuildJob).with(character.id).exactly(:once)
      end
    end

    it 'queues one build when a source and a build column change in one save' do
      expect { character.update!(wiki_raw: '{{Character|z=1}}', element: 4) }
        .to have_enqueued_job(CharacterSkills::BuildJob).with(character.id).exactly(:once)
    end

    it 'queues none when the assigned text is what is stored' do
      expect { character.update!(wiki_raw: '{{Character}}') }.not_to have_enqueued_job(CharacterSkills::BuildJob)
    end

    it 'queues a build when a source is written through the store' do
      expect { Source.put(character, :game_raw_en, { 'a' => 1 }) }
        .to have_enqueued_job(CharacterSkills::BuildJob).with(character.id).exactly(:once)
    end

    it 'queues none for an unchanged store write, or one inside without_skill_build' do
      Source.put(character, :game_raw_en, { 'a' => 1 }, skip_owner_hook: true)

      expect { Source.put(character, :game_raw_en, { 'a' => 1 }) }.not_to have_enqueued_job(CharacterSkills::BuildJob)
      expect { described_class.without_skill_build { Source.put(character, :game_raw_en, { 'a' => 2 }) } }
        .not_to have_enqueued_job(CharacterSkills::BuildJob)
    end

    it 'decides at the write, so a transaction committed after without_skill_build queues none' do
      expect do
        ActiveRecord::Base.transaction do
          described_class.without_skill_build { character.update!(wiki_raw: '{{Character|w=1}}') }
        end
      end.not_to have_enqueued_job(CharacterSkills::BuildJob)
    end

    it 'queues none inside without_skill_build' do
      expect { described_class.without_skill_build { character.update!(wiki_raw: '{{Character|y=1}}') } }
        .not_to have_enqueued_job(CharacterSkills::BuildJob)
      expect(described_class.skip_skill_build).to be_falsey
    end
  end
end
