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
end
