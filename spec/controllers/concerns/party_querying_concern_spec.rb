# frozen_string_literal: true

require 'rails_helper'

# Dummy class including PartyQueryingConcern so that we can test its methods in isolation.
class DummyQueryClass
  include PartyQueryingConcern

  # Define a setter and getter for current_user so that the concern can call it.
  attr_accessor :current_user

  # Provide a basic params method for testing.
  attr_writer :params

  def params
    @params ||= {}
  end
end

RSpec.describe DummyQueryClass do
  let(:dummy) { DummyQueryClass.new }

  describe '#build_filters' do
    context 'when parameters are provided' do
      before do
        dummy.params.merge!({
                              element: '3',
                              raid: 'raid_id_123',
                              recency: '3600',
                              full_auto: '1',
                              auto_guard: '0',
                              charge_attack: '1',
                              characters_count: '4',
                              summons_count: '3',
                              weapons_count: '6'
                            })
      end

      it 'builds a hash with converted values and a date range for created_at' do
        filters = dummy.build_filters
        expect(filters[:element]).to eq(3)
        expect(filters[:raid_id]).to eq('raid_id_123')
        expect(filters[:created_at]).to be_a(Range)
        expect(filters[:full_auto]).to eq(1)
        expect(filters[:auto_guard]).to eq(0)
        expect(filters[:charge_attack]).to eq(1)
        # For object count ranges, we expect a Range.
        expect(filters[:characters_count]).to be_a(Range)
        expect(filters[:summons_count]).to be_a(Range)
        expect(filters[:weapons_count]).to be_a(Range)
      end
    end

    context 'when no parameters are provided' do
      before { dummy.params = {} }
      it 'returns the default quality filters' do
        filters = dummy.build_filters
        expect(filters).to include(
                             characters_count: (PartyConstants::DEFAULT_MIN_CHARACTERS..PartyConstants::MAX_CHARACTERS),
                             summons_count: (PartyConstants::DEFAULT_MIN_SUMMONS..PartyConstants::MAX_SUMMONS),
                             weapons_count: (PartyConstants::DEFAULT_MIN_WEAPONS..PartyConstants::MAX_WEAPONS)
                           )
      end
    end
  end

  describe '#build_date_range' do
    context 'with a recency parameter' do
      before { dummy.params = { recency: '7200' } }
      it 'returns a valid date range' do
        date_range = dummy.build_date_range
        expect(date_range).to be_a(Range)
        expect(date_range.begin).to be <= DateTime.current
        expect(date_range.end).to be >= DateTime.current - 2.hours
      end
    end

    context 'without a recency parameter' do
      before { dummy.params = {} }
      it 'returns nil' do
        expect(dummy.build_date_range).to be_nil
      end
    end
  end

  describe '#build_count' do
    it 'returns the default value when blank' do
      expect(dummy.build_count('', 3)).to eq(3)
    end

    it 'converts string values to integer' do
      expect(dummy.build_count('5', 3)).to eq(5)
    end
  end

  describe '#build_option' do
    it 'returns nil for blank or -1 values' do
      expect(dummy.build_option('')).to be_nil
      expect(dummy.build_option('-1')).to be_nil
    end

    it 'returns the integer value for valid input' do
      expect(dummy.build_option('2')).to eq(2)
    end
  end

  describe '#grid_table_and_object_table' do
    it 'maps id starting with "3" to grid_characters and characters' do
      tables = dummy.grid_table_and_object_table('300000')
      expect(tables).to eq(%w[grid_characters characters])
    end

    it 'maps id starting with "2" to grid_summons and summons' do
      tables = dummy.grid_table_and_object_table('200000')
      expect(tables).to eq(%w[grid_summons summons])
    end

    it 'maps id starting with "1" to grid_weapons and weapons' do
      tables = dummy.grid_table_and_object_table('100000')
      expect(tables).to eq(%w[grid_weapons weapons])
    end

    it 'returns [nil, nil] for an unknown prefix' do
      tables = dummy.grid_table_and_object_table('900000')
      expect(tables).to eq([nil, nil])
    end
  end

  describe '#remixed_name' do
    context 'when current_user is present' do
      let(:user) { build(:user, language: 'en') }
      before { dummy.instance_variable_set(:@current_user, user) }
      it 'returns a remix name in English' do
        expect(dummy.remixed_name('Original Party')).to eq('Remix of Original Party')
      end

      context 'when user language is Japanese' do
        let(:user) { build(:user, language: 'ja') }
        before { dummy.instance_variable_set(:@current_user, user) }
        it 'returns a remix name in Japanese' do
          expect(dummy.remixed_name('オリジナル')).to eq('オリジナルのリミックス')
        end
      end
    end

    context 'when current_user is nil' do
      before { dummy.instance_variable_set(:@current_user, nil) }
      it 'returns a remix name in English by default' do
        expect(dummy.remixed_name('Original Party')).to eq('Remix of Original Party')
      end
    end
  end

  # Debug block: prints debugging information if an example fails.
  after(:each) do |example|
    if example.exception && defined?(response) && response.present?
      error_message = begin
                        JSON.parse(response.body)['exception']
                      rescue JSON::ParserError
                        response.body
                      end

      puts "\nDEBUG: Error Message for '#{example.full_description}': #{error_message}"

      # Parse once and grab the trace safely
      parsed_body = JSON.parse(response.body)
      trace = parsed_body.dig('traces', 'Application Trace')
      ap trace if trace # Only print if trace is not nil
    end
  end
end
