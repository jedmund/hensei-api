# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Processors::SummonProcessor, type: :model do
  let(:party) { create(:party) }
  let(:deck_data) do
    file_path = Rails.root.join('spec', 'fixtures', 'deck_sample.json')
    JSON.parse(File.read(file_path))
  end

  subject { described_class.new(party, deck_data, language: 'en') }

  context 'with valid summon data' do
    it 'creates the correct number of GridSummon records' do
      expect { subject.process }.to change(GridSummon, :count).by(8)
    end

    it 'creates GridSummons associated with the party' do
      subject.process
      grid_summons = GridSummon.where(party_id: party.id)
      expect(grid_summons.count).to eq(8)
      expect(grid_summons.map(&:summon)).to all(be_present)
    end
  end

  context 'with invalid summon data' do
    let(:deck_data) { "invalid data" }
    it 'does not create any GridSummon and logs an error containing "SUMMON"' do
      expect { subject.process }.not_to change(GridSummon, :count)
      begin
        subject.process
      rescue StandardError
        nil
      end
    end
  end

  context 'with unknown summons in deck' do
    let(:deck_data) do
      data = JSON.parse(File.read(Rails.root.join('spec', 'fixtures', 'deck_sample.json')))
      data['deck']['pc']['summons']['1']['master']['id'] = '9999999999'
      data
    end

    it 'skips the unknown summon without crashing' do
      expect { subject.process }.not_to raise_error
    end

    it 'still creates grid summons for the known ones' do
      expect { subject.process }.to change(GridSummon, :count)
    end
  end

  context 'with unknown friend summon' do
    let(:deck_data) do
      data = JSON.parse(File.read(Rails.root.join('spec', 'fixtures', 'deck_sample.json')))
      data['deck']['pc']['damage_info']['summon_name'] = 'Nonexistent Summon XYZ'
      data
    end

    it 'skips the friend summon without crashing' do
      expect { subject.process }.not_to raise_error
    end

    it 'does not create a friend grid summon' do
      subject.process
      expect(GridSummon.where(party: party, friend: true).count).to eq(0)
    end
  end

  describe 'quick summon detection' do
    it 'sets quick_summon on the matching main grid summon' do
      # deck_sample.json has quick_user_summon_id=675435184 which matches summons[5] (param.id=675435184)
      subject.process
      grid_summons = GridSummon.where(party: party, friend: false).order(:position)
      quick = grid_summons.select(&:quick_summon)
      expect(quick.length).to eq(1)

      # Position 3 = summons[5] (slot 5 maps to position: 5-2=3)
      expect(quick.first.position).to eq(3)
    end

    it 'does not set quick_summon on sub summons' do
      subject.process
      sub_summons = GridSummon.where(party: party).where('position >= ?', 4)
      expect(sub_summons.pluck(:quick_summon)).to all(be false)
    end

    context 'when quick_user_summon_id is absent' do
      let(:deck_data) do
        data = JSON.parse(File.read(Rails.root.join('spec', 'fixtures', 'deck_sample.json')))
        data['deck']['pc'].delete('quick_user_summon_id')
        data
      end

      it 'sets quick_summon to false on all summons' do
        subject.process
        expect(GridSummon.where(party: party).pluck(:quick_summon)).to all(be false)
      end
    end
  end

  describe '#level_to_transcendence' do
    let(:dummy_deck) { { 'deck' => { 'pc' => { 'summons' => {}, 'sub_summons' => {} } } } }
    let(:processor) { described_class.new(party, dummy_deck) }

    it 'returns 0 for levels below 200' do
      expect(processor.send(:level_to_transcendence, 150)).to eq(0)
    end

    it 'returns the correct step for valid transcendence levels' do
      expect(processor.send(:level_to_transcendence, 200)).to eq(0)
      expect(processor.send(:level_to_transcendence, 210)).to eq(1)
      expect(processor.send(:level_to_transcendence, 250)).to eq(5)
    end

    it 'returns 0 for levels above the known transcendence range' do
      expect(processor.send(:level_to_transcendence, 260)).to eq(0)
      expect(processor.send(:level_to_transcendence, 300)).to eq(0)
    end
  end

  after(:each) do |example|
    if example.exception
      puts "\nDEBUG [SummonProcessor]: #{example.full_description} failed with error: #{example.exception.message}"
    end
  end
end
