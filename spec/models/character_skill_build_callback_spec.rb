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

    %w[wiki_raw wiki_raw_jp game_raw_en game_raw_jp element].each do |column|
      it "queues a build when #{column} changes" do
        value = { 'wiki_raw' => '{{Character|x=1}}', 'wiki_raw_jp' => '<p>x</p>', 'game_raw_en' => { 'a' => 1 },
                  'game_raw_jp' => { 'a' => 1 }, 'element' => 3 }.fetch(column)
        expect { character.update!(column => value) }
          .to have_enqueued_job(CharacterSkills::BuildJob).with(character.id).exactly(:once)
      end
    end

    it 'queues none inside without_skill_build' do
      expect { described_class.without_skill_build { character.update!(wiki_raw: '{{Character|y=1}}') } }
        .not_to have_enqueued_job(CharacterSkills::BuildJob)
      expect(described_class.skip_skill_build).to be_falsey
    end
  end
end
