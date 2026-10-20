# frozen_string_literal: true

require 'rails_helper'
require 'rake'

RSpec.describe 'character skill build tasks' do
  let(:summary) { CharacterSkills::Build::Runner::Summary.new(failed: 0, empty: 0, results: []) }
  let(:runner) { instance_double(CharacterSkills::Build::Runner, call: summary) }

  before(:all) do
    Rails.application.load_tasks unless Rake::Task.task_defined?('granblue:build_character_skills')
  end

  around do |example|
    keys = %w[ids all mode limit icons CHARACTER_SKILL_BUILD]
    saved = keys.to_h { |k| [k, ENV.fetch(k, nil)] }
    keys.each { |k| ENV.delete(k) }
    example.run
  ensure
    saved.each { |k, v| v.nil? ? ENV.delete(k) : ENV[k] = v }
  end

  before do
    allow(CharacterSkills::Build::Runner).to receive(:new).and_return(runner)
    allow(ActiveRecord::Base).to receive(:logger=)
  end

  def invoke(name)
    Rake::Task[name].reenable
    Rake::Task[name].invoke
  end

  describe 'granblue:build_character_skills' do
    it 'defaults to shadow and passes ids and all' do
      ENV['ids'] = '3040252000, 3040164000'
      ENV['all'] = 'true'
      invoke('granblue:build_character_skills')
      expect(CharacterSkills::Build::Runner).to have_received(:new)
        .with(mode: 'shadow', ids: %w[3040252000 3040164000], all: true, diff_limit: nil, enqueue_icons: true)
    end

    it 'writes when CHARACTER_SKILL_BUILD=write' do
      ENV['CHARACTER_SKILL_BUILD'] = 'write'
      invoke('granblue:build_character_skills')
      expect(CharacterSkills::Build::Runner).to have_received(:new).with(hash_including(mode: 'write'))
    end

    it 'skips icon downloads with icons=false' do
      ENV['icons'] = 'false'
      invoke('granblue:build_character_skills')
      expect(CharacterSkills::Build::Runner).to have_received(:new).with(hash_including(enqueue_icons: false))
    end

    it 'exits nonzero when a character failed' do
      summary.failed = 1
      expect { invoke('granblue:build_character_skills') }.to raise_error(SystemExit)
    end
  end

  describe 'granblue:character_skill_drift' do
    it 'runs shadow over every character and passes when nothing differs' do
      expect { invoke('granblue:character_skill_drift') }.not_to raise_error
      expect(CharacterSkills::Build::Runner).to have_received(:new).with(mode: 'shadow', all: true, diff_limit: 50)
    end

    it 'exits nonzero when a character differs' do
      summary.results = [CharacterSkills::Build::Runner::Result.new(changes: [:a_change])]
      expect { invoke('granblue:character_skill_drift') }.to raise_error(SystemExit)
    end
  end

  it 'retires granblue:parse_character_skills with a pointer to the new task' do
    expect { invoke('granblue:parse_character_skills') }.to raise_error(SystemExit).and output(/build_character_skills/).to_stderr
  end
end
