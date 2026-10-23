# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Solomonis::ReportParser do
  let(:report) do
    JSON.parse(Rails.root.join('spec/fixtures/solomonis/report-detail.json').read)['report']
  end
  let(:now) { Time.zone.parse('2026-10-12T12:00:00+09:00') }

  def parser(overrides = {}, at: now)
    described_class.new(report.merge(overrides), now: at)
  end

  it 'reads the IDs from the image fields' do
    expect(parser.route_evoker_granblue_id).to eq('3040169000')
    expect(parser.job_granblue_id).to eq('130501')
    expect(parser.characters).to eq(
      [
        { granblue_id: '3040265000', art: '02' }, { granblue_id: '3040554000', art: '02' },
        { granblue_id: '3040639000', art: '02' }, { granblue_id: '3040610000', art: '02' },
        { granblue_id: '3040169000', art: '04' }
      ]
    )
  end

  it 'reads counts sent as strings' do
    expect(parser.turn_count).to eq(109)
    expect(parser.spacebook_status_count).to eq(71)
    expect(parser.expedition_attributes[:stats]['points_earned']).to eq(2924)
  end

  it 'strips the default name' do
    expect(parser.deck_name).to eq('Nier Party')
  end

  describe 'ended_at' do
    def ended_at(value, at: now)
      parser({ 'ended_at' => value }, at: at).expedition_attributes[:ended_at]
    end

    it 'is in JST, in the current year when that is not in the future' do
      expect(ended_at('10/11 16:38')).to eq(Time.zone.parse('2026-10-11T16:38:00+09:00'))
    end

    it 'falls back to the previous year for a date after now' do
      expect(ended_at('12/31 23:00')).to eq(Time.zone.parse('2025-12-31T23:00:00+09:00'))
    end

    it 'allows a little clock skew' do
      expect(ended_at('10/12 12:30')).to eq(Time.zone.parse('2026-10-12T12:30:00+09:00'))
    end

    it 'finds the last leap year for February 29' do
      expect(ended_at('2/29 10:00')).to eq(Time.zone.parse('2024-02-29T10:00:00+09:00'))
    end

    it 'leaves an unreadable date empty, with a warning' do
      p = parser({ 'ended_at' => '13/45 99:00' })

      expect(p.expedition_attributes[:ended_at]).to be_nil
      expect(p.warnings).to eq(['ended_at "13/45 99:00" isn\'t a date; left empty'])
    end
  end

  describe 'outcome' do
    def outcome(overrides)
      p = parser(overrides)
      [p.expedition_attributes[:outcome], p.warnings]
    end

    it 'follows boss_count' do
      expect(outcome('is_success' => false, 'boss_count' => '0')).to eq(['miasma_1', []])
      expect(outcome('is_success' => false, 'boss_count' => 1)).to eq(['miasma_2', []])
      expect(outcome('is_success' => true, 'boss_count' => '2')).to eq(['cleared', []])
    end

    it 'warns when is_success disagrees, and keeps boss_count' do
      expect(outcome('is_success' => true, 'boss_count' => '1'))
        .to eq(['miasma_2', ['is_success is true but boss_count is 1; outcome follows boss_count']])
      expect(outcome('is_success' => 0, 'boss_count' => '2'))
        .to eq(['cleared', ['is_success is false but boss_count is 2; outcome follows boss_count']])
    end

    it 'is empty when boss_count is missing or out of range' do
      expect(outcome('boss_count' => nil)).to eq([nil, ['boss_count is missing; outcome left empty']])
      expect(outcome('boss_count' => '3')).to eq([nil, ['boss_count 3 is out of range; outcome left empty']])
      expect(outcome('boss_count' => 'x')).to eq([nil, ["boss_count isn't a count; ignored"]])
    end
  end

  it 'ignores counts that are not counts' do
    p = parser({ 'normal_enemy_count' => '-3', 'total_turn' => 'many' })

    expect(p.expedition_attributes[:stats]).not_to have_key('battle')
    expect(p.turn_count).to be_nil
    expect(p.warnings).to contain_exactly("normal_enemy_count isn't a count; ignored", "total_turn isn't a count; ignored")
  end

  it 'skips character fields that are not image IDs' do
    p = parser({ 'npc1_image_id' => 'abc', 'npc2_image_id' => nil })

    expect(p.characters.size).to eq(3)
    expect(p.warnings).to eq(["npc1_image_id isn't a character image ID; skipped"])
  end
end
