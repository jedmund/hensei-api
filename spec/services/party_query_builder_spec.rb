# frozen_string_literal: true

# This spec verifies that PartyQueryBuilder correctly builds an ActiveRecord
# query based on provided parameters. It tests both the overall build process and
# individual helper methods.
#
require 'rails_helper'

RSpec.describe PartyQueryBuilder, type: :model do
  let(:base_query) { Party.all } # Use Party.all as our starting query.
  let(:params) do
    {
      element: '3',
      raid: '123e4567-e89b-12d3-a456-426614174000',
      recency: '3600',
      full_auto: '1',
      auto_guard: '0',
      charge_attack: '1',
      weapons_count: '', # blank => should use default
      characters_count: '4',
      summons_count: '2',
      includes: '300001,200002',
      excludes: '100003',
      name_quality: '1' # dummy flag for testing name_quality clause
    }
  end
  let(:current_user) { create(:user) }
  let(:options) { {} }

  subject { described_class.new(base_query, params: params, current_user: current_user, options: options) }

  describe '#build' do
    context 'with all filters provided' do
      it 'returns an ActiveRecord::Relation with filters applied' do
        query = subject.build
        sql = query.to_sql
        # Expect the element filter to be applied (converted to integer)
        expect(sql).to include('"parties"."element" = 3')
        # Expect the raid filter to be applied
        expect(sql).to match(/"parties"."raid_id"\s*=\s*'123e4567-e89b-12d3-a456-426614174000'/)
        # Expect a created_at range condition from the recency param
        expect(sql).to include('"parties"."created_at" BETWEEN')
        # Expect object count filtering for characters_count (range clause)
        expect(sql).to include('characters_count')
        # Expect the name quality stub condition
        expect(sql).to include("name NOT LIKE 'Untitled%'")
        # Expect that includes and excludes clauses (EXISTS and NOT EXISTS) are added
        expect(sql).to include('EXISTS (')
        expect(sql).to include('NOT EXISTS (')
      end
    end

    context 'when default_status option is provided' do
      let(:options) { { default_status: 'active' } }
      it 'applies the default status filter' do
        query = subject.build
        sql = query.to_sql
        expect(sql).to include('"parties"."status" = \'active\'')
      end
    end

    context 'when current_user is not admin and skip_privacy is not set' do
      it 'applies the privacy filter (visibility = 1)' do
        query = subject.build
        sql = query.to_sql
        expect(sql).to include('visibility = 1')
      end
    end

    context 'when current_user is admin' do
      let(:current_user) { create(:user, role: 9) }
      it 'does not apply the privacy filter' do
        query = subject.build
        sql = query.to_sql
        expect(sql).not_to include('visibility = 1')
      end
    end

    context 'when skip_privacy option is set' do
      let(:options) { { skip_privacy: true } }
      it 'does not apply the privacy filter even for non-admins' do
        query = subject.build
        sql = query.to_sql
        expect(sql).not_to include('visibility = 1')
      end
    end

    it 'returns an ActiveRecord::Relation object' do
      expect(subject.build).to be_a(ActiveRecord::Relation)
    end
  end

  describe 'private helper methods' do
    describe '#grid_table_and_object_table' do
      it 'returns grid_characters and characters for an id starting with "3"' do
        result = subject.send(:grid_table_and_object_table, '300001')
        expect(result).to eq(%w[grid_characters characters])
      end

      it 'returns grid_summons and summons for an id starting with "2"' do
        result = subject.send(:grid_table_and_object_table, '200001')
        expect(result).to eq(%w[grid_summons summons])
      end

      it 'returns grid_weapons and weapons for an id starting with "1"' do
        result = subject.send(:grid_table_and_object_table, '100001')
        expect(result).to eq(%w[grid_weapons weapons])
      end

      it 'returns [nil, nil] for an unknown prefix' do
        result = subject.send(:grid_table_and_object_table, '900001')
        expect(result).to eq([nil, nil])
      end
    end

    describe '#build_date_range' do
      it 'returns a range when recency parameter is provided' do
        range = subject.send(:build_date_range)
        expect(range).to be_a(Range)
        expect(range.begin).to be <= DateTime.current
        # The range should span from beginning of the day to now
        expect(range.end).to be >= DateTime.current - 3600.seconds
      end

      it 'returns nil when recency parameter is missing' do
        new_params = params.dup
        new_params.delete(:recency)
        builder = described_class.new(base_query, params: new_params, current_user: current_user, options: options)
        expect(builder.send(:build_date_range)).to be_nil
      end
    end

    describe '#build_count' do
      it 'returns the default value when given a blank parameter' do
        expect(subject.send(:build_count, '', 3)).to eq(3)
      end

      it 'converts string numbers to integer' do
        expect(subject.send(:build_count, '5', 3)).to eq(5)
      end
    end

    describe '#build_option' do
      it 'returns nil if the value is blank' do
        expect(subject.send(:build_option, '')).to be_nil
      end

      it 'returns nil if the value is -1' do
        expect(subject.send(:build_option, '-1')).to be_nil
      end

      it 'returns the integer value for valid input' do
        expect(subject.send(:build_option, '2')).to eq(2)
      end
    end

    describe '#apply_includes and #apply_excludes' do
      context 'with a valid includes parameter' do
        let(:includes_param) { '300001' } # should map to grid_characters/characters
        it 'adds an EXISTS clause to the query' do
          query = subject.send(:apply_includes, base_query, includes_param)
          sql = query.to_sql
          expect(sql).to include('EXISTS (')
          expect(sql).to include('grid_characters')
          expect(sql).to include('characters')
        end
      end

      context 'with a valid excludes parameter' do
        let(:excludes_param) { '100001' } # should map to grid_weapons/weapons
        it 'adds a NOT EXISTS clause to the query' do
          query = subject.send(:apply_excludes, base_query, excludes_param)
          sql = query.to_sql
          expect(sql).to include('NOT EXISTS (')
          expect(sql).to include('grid_weapons')
          expect(sql).to include('weapons')
        end
      end

      context 'with an unknown prefix in includes/excludes' do
        let(:bad_param) { '900001' }
        it 'skips the condition for includes' do
          query = subject.send(:apply_includes, base_query, bad_param)
          sql = query.to_sql
          expect(sql).not_to include('EXISTS (')
        end

        it 'skips the condition for excludes' do
          query = subject.send(:apply_excludes, base_query, bad_param)
          sql = query.to_sql
          expect(sql).not_to include('NOT EXISTS (')
        end
      end

      context 'when apply_defaults option is true' do
        subject do
          described_class.new(
            base_query,
            params: params,
            current_user: current_user,
            options: { apply_defaults: true }
          )
        end

        it 'adds count filters to the query' do
          query = subject.build
          sql = query.to_sql
          expect(sql).to include('"weapons_count" BETWEEN')
          expect(sql).to include('"characters_count" BETWEEN')
          expect(sql).to include('"summons_count" BETWEEN')
        end
      end

      context 'when apply_defaults option is false (or not provided)' do
        let(:blanked_params) do
          {
            element: '3',
            raid: '123e4567-e89b-12d3-a456-426614174000',
            recency: '3600',
            full_auto: '1',
            auto_guard: '0',
            charge_attack: '1',
            weapons_count: '', # blank => should use default
            characters_count: '',
            summons_count: '',
            includes: '300001,200002',
            excludes: '100003',
            name_quality: '1' # dummy flag for testing name_quality clause
          }
        end

        subject do
          described_class.new(
            base_query,
            params: blanked_params,
            current_user: current_user,
            options: {}
          )
        end

        it 'does not add count filters to the query' do
          query = subject.build
          sql = query.to_sql
          expect(sql).not_to include('weapons_count BETWEEN')
          expect(sql).not_to include('characters_count BETWEEN')
          expect(sql).not_to include('summons_count BETWEEN')
        end
      end
    end
  end
end
