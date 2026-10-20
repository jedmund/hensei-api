# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Granblue::Parsers::CharacterSkillParser, '.build_status_lookup' do
  def status(name, category, at)
    Status.create!(name_en: name, category: category, created_at: at)
  end

  def resolved(name) = described_class.build_status_lookup[:by_name].fetch(name.downcase)

  let(:t0) { Time.zone.parse('2026-06-12 00:00') }

  it 'takes the majority category of same-name rows, then the oldest row in it' do
    status('DEF Up', 'debuff', t0) # oldest, but outvoted
    first_buff = status('DEF Up', 'buff', t0 + 1.day)
    status('DEF Up', 'buff', t0 + 2.days)
    expect(resolved('def up')).to eq(first_buff)
  end

  it 'gives a debuff majority to the debuff rows' do
    status('Thunderstruck', 'buff', t0)
    oldest_debuff = status('Thunderstruck', 'debuff', t0 + 1.day)
    status('Thunderstruck', 'debuff', t0 + 2.days)
    expect(resolved('Thunderstruck')).to eq(oldest_debuff)
  end

  it 'breaks a buff/debuff tie toward buff' do
    status('Charge Boost', 'debuff', t0)
    buff = status('Charge Boost', 'buff', t0 + 1.day)
    expect(resolved('Charge Boost')).to eq(buff)
  end

  it 'lets a field row beat a buff majority' do
    status('Sun-touched Paradise', 'buff', t0)
    status('Sun-touched Paradise', 'buff', t0 + 1.day)
    field = status('Sun-touched Paradise', 'field', t0 + 2.days)
    expect(resolved('Sun-touched Paradise')).to eq(field)
  end

  it "doesn't let a field row beat a debuff majority" do
    debuff = status('Malice', 'debuff', t0)
    status('Malice', 'debuff', t0 + 1.day)
    status('Malice', 'field', t0 + 2.days)
    expect(resolved('Malice')).to eq(debuff)
  end

  it 'resolves a mixed group the same way whatever order the rows load in, and a later same-category row changes nothing' do
    a = status('TA Up', 'buff', t0 + 1.day)
    status('TA Up', 'debuff', t0)
    status('TA Up', 'buff', t0 + 3.days)
    expect(resolved('TA Up')).to eq(a)
    status('TA Up', 'buff', t0 + 4.days)
    expect(resolved('TA Up')).to eq(a)
  end

  it 'keeps a single row and indexes every status by id' do
    only = status('Veil', 'buff', t0)
    other = status('Veil Two', 'special', t0)
    lookup = described_class.build_status_lookup
    expect(lookup[:by_name]['veil']).to eq(only)
    expect(lookup[:by_name]['veil two']).to eq(other)
    expect(lookup[:by_id].keys).to contain_exactly(only.id, other.id)
  end
end
