# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CharacterSkills::BuildLock do
  include BuildLockHelpers

  it 'runs the block and releases its locks' do
    ran = false
    expect(described_class.all { ran = true }).to be(true)
    expect(ran).to be(true)
    expect(build_locks_free?).to be(true)
  end

  it 'runs builds of different characters side by side' do
    held_elsewhere(:character, 'a') do
      expect(described_class.character('b') { nil }).to be(true)
    end
  end

  it "doesn't run a build of the same character twice at once" do
    ran = false
    held_elsewhere(:character, 'a') { expect(described_class.character('a') { ran = true }).to be(false) }
    expect(ran).to be(false)
  end

  it "doesn't run the stale build during a character build, or a character build during it" do
    held_elsewhere(:character, 'a') { expect(described_class.all { nil }).to be(false) }
    held_elsewhere(:all) { expect(described_class.character('b') { nil }).to be(false) }
  end

  it 'releases the locks of a character build' do
    described_class.character('a') { nil }
    expect(build_locks_free?).to be(true)
  end

  it 'releases its locks when the block raises' do
    expect { described_class.all { raise 'boom' } }.to raise_error('boom')
    expect(build_locks_free?).to be(true)
  end

  describe 'with wait:' do
    it 'waits for a build that finishes in time, then runs' do
      ran = false
      held_elsewhere(:character, 'a', release_after: 0.3) do
        expect(described_class.character('a', wait: 5) { ran = true }).to be(true)
      end
      expect(ran).to be(true)
    end

    it 'gives up after the wait and runs nothing' do
      ran = false
      held_elsewhere(:all) do
        started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        expect(described_class.character('a', wait: 0.3) { ran = true }).to be(false)
        expect(Process.clock_gettime(Process::CLOCK_MONOTONIC) - started).to be_between(0.25, 2)
      end
      expect(ran).to be(false)
      expect(build_locks_free?).to be(true)
    end

    it 'puts lock_timeout back after waiting' do
      before = ActiveRecord::Base.connection.select_value("SELECT current_setting('lock_timeout')")
      described_class.all(wait: 1) { nil }
      held_elsewhere(:all) { described_class.all(wait: 0.2) { nil } }
      expect(ActiveRecord::Base.connection.select_value("SELECT current_setting('lock_timeout')")).to eq(before)
    end
  end
end
