# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Granblue::Transformers::BaseDeckTransformer do
  before do
    allow(Rails.logger).to receive_messages(info: nil, debug: nil, error: nil)
  end

  describe '#transform' do
    context 'with ActionController::Parameters input' do
      it 'returns symbolized hash as-is when :name key present' do
        params = ActionController::Parameters.new(name: 'My Party', element: 3)
        params.permit!
        result = described_class.new(params).transform
        expect(result[:name]).to eq('My Party')
        expect(result[:element]).to eq(3)
      end
    end

    context 'with raw game data' do
      let(:data) do
        {
          'import' => {
            'deck' => {
              'name' => 'Test Deck',
              'pc' => {
                'job' => { 'master' => { 'name' => 'Dark Fencer' } },
                'isExtraDeck' => false,
                'set_action' => [[{ 'name' => 'Miserable Mist' }, { 'name' => 'Armor Break' }]],
                'weapons' => {},
                'summons' => {},
                'sub_summons' => {},
                'quick_user_summon_id' => nil,
                'damage_info' => { 'summon_name' => 'Lucifer' }
              },
              'npc' => {}
            }
          }
        }
      end

      it 'extracts all deck fields' do
        result = described_class.new(data).transform

        aggregate_failures do
          expect(result[:lang]).to eq('en')
          expect(result[:name]).to eq('Test Deck')
          expect(result[:class]).to eq('Dark Fencer')
          expect(result[:extra]).to be false
          expect(result[:subskills]).to eq(['Miserable Mist', 'Armor Break'])
          expect(result[:friend_summon]).to eq('Lucifer')
        end
      end

      it 'defaults name to Untitled when missing' do
        data['import']['deck']['name'] = nil
        result = described_class.new(data).transform
        expect(result[:name]).to eq('Untitled')
      end
    end

    context 'with missing import data' do
      it 'returns empty hash' do
        expect(described_class.new({}).transform).to eq({})
      end
    end

    context 'with missing deck or pc' do
      it 'returns empty hash when deck is nil' do
        data = { 'import' => { 'deck' => nil } }
        expect(described_class.new(data).transform).to eq({})
      end
    end
  end

  describe 'subskill extraction' do
    it 'extracts skill names from set_action' do
      data = {
        'import' => {
          'deck' => {
            'pc' => {
              'job' => { 'master' => { 'name' => 'Fighter' } },
              'set_action' => [[{ 'name' => 'Skill A' }]],
              'weapons' => {}, 'summons' => {}, 'sub_summons' => {},
              'damage_info' => {}
            },
            'npc' => {}
          }
        }
      }
      result = described_class.new(data).transform
      expect(result[:subskills]).to eq(['Skill A'])
    end

    it 'returns empty array for nil set_action' do
      data = {
        'import' => {
          'deck' => {
            'pc' => {
              'job' => { 'master' => { 'name' => 'Fighter' } },
              'set_action' => nil,
              'weapons' => {}, 'summons' => {}, 'sub_summons' => {},
              'damage_info' => {}
            },
            'npc' => {}
          }
        }
      }
      result = described_class.new(data).transform
      expect(result[:subskills]).to eq([])
    end
  end
end
