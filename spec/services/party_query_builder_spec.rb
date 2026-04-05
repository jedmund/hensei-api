# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PartyQueryBuilder, type: :model do
  let(:base_query) { Party.all }
  let(:current_user) { create(:user) }
  let(:options) { {} }
  let(:params) { {} }

  subject { described_class.new(base_query, params: params, current_user: current_user, options: options) }

  describe '#build' do
    it 'returns an ActiveRecord::Relation' do
      expect(subject.build).to be_a(ActiveRecord::Relation)
    end

    context 'element filter' do
      let!(:fire_party) { create(:party, element: 1, visibility: 1) }
      let!(:water_party) { create(:party, element: 2, visibility: 1) }
      let(:params) { { element: '1' } }

      it 'returns only parties matching the element' do
        results = subject.build
        expect(results).to include(fire_party)
        expect(results).not_to include(water_party)
      end
    end

    context 'raid filter' do
      let(:raid) { create(:raid) }
      let!(:matching_party) { create(:party, raid: raid, visibility: 1) }
      let!(:other_party) { create(:party, visibility: 1) }

      context 'by UUID' do
        let(:params) { { raid: raid.id } }

        it 'returns only parties for the specified raid' do
          results = subject.build
          expect(results).to include(matching_party)
          expect(results).not_to include(other_party)
        end
      end

      context 'by slug' do
        let(:params) { { raid: raid.slug } }

        it 'resolves the slug and returns matching parties' do
          results = subject.build
          expect(results).to include(matching_party)
          expect(results).not_to include(other_party)
        end
      end
    end

    context 'recency filter' do
      let!(:recent_party) { create(:party, created_at: 1.hour.ago, visibility: 1) }
      let!(:old_party) { create(:party, created_at: 1.year.ago, visibility: 1) }
      let(:params) { { recency: '86400' } }

      it 'returns only parties created within the recency window' do
        results = subject.build
        expect(results).to include(recent_party)
        expect(results).not_to include(old_party)
      end
    end

    context 'full_auto filter' do
      let!(:full_auto_party) { create(:party, full_auto: true, visibility: 1) }
      let!(:manual_party) { create(:party, full_auto: false, visibility: 1) }
      let(:params) { { full_auto: '1' } }

      it 'returns only full_auto parties when filter is 1' do
        results = subject.build
        expect(results).to include(full_auto_party)
        expect(results).not_to include(manual_party)
      end
    end

    context 'solo filter' do
      let!(:solo_party) { create(:party, solo: true, visibility: 1) }
      let!(:group_party) { create(:party, solo: false, visibility: 1) }
      let(:params) { { solo: '1' } }

      it 'returns only solo parties when filter is 1' do
        results = subject.build
        expect(results).to include(solo_party)
        expect(results).not_to include(group_party)
      end
    end

    context 'name_quality filter' do
      let!(:named_party) { create(:party, name: 'My Build', visibility: 1) }
      let!(:untitled_party) { create(:party, name: 'Untitled', visibility: 1) }
      let(:params) { { name_quality: '1' } }

      it 'excludes untitled parties' do
        results = subject.build
        expect(results).to include(named_party)
        expect(results).not_to include(untitled_party)
      end
    end

    context 'boost_mod filter' do
      let!(:omega_party) { create(:party, boost_mod: 'omega', boost_side: 'double', visibility: 1) }
      let!(:primal_party) { create(:party, boost_mod: 'primal', boost_side: 'single', visibility: 1) }
      let(:params) { { boost_mod: 'omega' } }

      it 'returns only parties matching the boost mod' do
        results = subject.build
        expect(results).to include(omega_party)
        expect(results).not_to include(primal_party)
      end
    end

    context 'boost_side filter' do
      let!(:double_party) { create(:party, boost_mod: 'omega', boost_side: 'double', visibility: 1) }
      let!(:single_party) { create(:party, boost_mod: 'omega', boost_side: 'single', visibility: 1) }
      let(:params) { { boost_side: 'double' } }

      it 'returns only parties matching the boost side' do
        results = subject.build
        expect(results).to include(double_party)
        expect(results).not_to include(single_party)
      end
    end

    context 'combined boost_mod and boost_side filter' do
      let!(:omega_double) { create(:party, boost_mod: 'omega', boost_side: 'double', visibility: 1) }
      let!(:omega_single) { create(:party, boost_mod: 'omega', boost_side: 'single', visibility: 1) }
      let!(:primal_double) { create(:party, boost_mod: 'primal', boost_side: 'double', visibility: 1) }
      let(:params) { { boost_mod: 'omega', boost_side: 'double' } }

      it 'returns only parties matching both mod and side' do
        results = subject.build
        expect(results).to include(omega_double)
        expect(results).not_to include(omega_single)
        expect(results).not_to include(primal_double)
      end
    end
  end

  describe 'privacy filtering' do
    let!(:public_party) { create(:party, visibility: 1) }
    let!(:private_party) { create(:party, visibility: 3) }

    context 'as a regular user' do
      it 'returns only public parties' do
        results = subject.build
        expect(results).to include(public_party)
        expect(results).not_to include(private_party)
      end
    end

    context 'as an admin' do
      let(:current_user) { create(:user, role: 9) }

      context 'with admin_mode enabled' do
        let(:options) { { admin_mode: true } }

        it 'returns all parties including private ones' do
          results = subject.build
          expect(results).to include(public_party)
          expect(results).to include(private_party)
        end
      end

      context 'without admin_mode' do
        it 'returns only public parties' do
          results = subject.build
          expect(results).to include(public_party)
          expect(results).not_to include(private_party)
        end
      end
    end

    context 'with skip_privacy option' do
      let(:options) { { skip_privacy: true } }

      it 'returns all parties including private ones' do
        results = subject.build
        expect(results).to include(public_party)
        expect(results).to include(private_party)
      end
    end

    context 'when user is in a crew with shared parties' do
      let(:crew) { create(:crew) }
      let(:current_user) { create(:user, crew: crew) }
      let!(:shared_party) { create(:party, visibility: 3) }

      before do
        create(:crew_membership, crew: crew, user: current_user) unless crew.crew_memberships.exists?(user: current_user)
        create(:party_share, party: shared_party, shareable: crew, shared_by: shared_party.user)
      end

      it 'returns public parties and crew-shared parties from other users' do
        results = subject.build
        expect(results).to include(public_party)
        expect(results).to include(shared_party)
        expect(results).not_to include(private_party)
      end
    end

    context 'when user has their own non-public parties shared with crew' do
      let(:crew) { create(:crew) }
      let(:current_user) { create(:user, crew: crew) }
      let!(:own_private_party) { create(:party, user: current_user, visibility: 3) }
      let!(:own_unlisted_party) { create(:party, user: current_user, visibility: 2) }
      let!(:own_public_party) { create(:party, user: current_user, visibility: 1) }

      before do
        create(:crew_membership, crew: crew, user: current_user) unless crew.crew_memberships.exists?(user: current_user)
        create(:party_share, party: own_private_party, shareable: crew, shared_by: current_user)
        create(:party_share, party: own_unlisted_party, shareable: crew, shared_by: current_user)
      end

      it 'excludes own private and unlisted parties even when crew-shared' do
        results = subject.build
        expect(results).to include(public_party)
        expect(results).to include(own_public_party)
        expect(results).not_to include(own_private_party)
        expect(results).not_to include(own_unlisted_party)
      end
    end
  end

  describe 'includes/excludes filtering' do
    let(:weapon) { Weapon.find_by!(granblue_id: '1040611300') }
    let(:character) { Character.find_by!(granblue_id: '3040087000') }

    let!(:party_with_weapon) { create(:party, visibility: 1) }
    let!(:party_with_character) { create(:party, visibility: 1) }
    let!(:empty_party) { create(:party, visibility: 1) }

    before do
      create(:grid_weapon, party: party_with_weapon, weapon: weapon)
      create(:grid_character, party: party_with_character, character: character)
    end

    context 'with includes' do
      let(:params) { { includes: weapon.granblue_id } }

      it 'returns only parties containing the specified item' do
        results = subject.build
        expect(results).to include(party_with_weapon)
        expect(results).not_to include(empty_party)
      end
    end

    context 'with excludes' do
      let(:params) { { excludes: weapon.granblue_id } }

      it 'excludes parties containing the specified item' do
        results = subject.build
        expect(results).not_to include(party_with_weapon)
        expect(results).to include(empty_party)
      end
    end

    context 'with unknown prefix' do
      let(:params) { { includes: '900001' } }

      it 'ignores the unknown ID and returns all visible parties' do
        results = subject.build
        expect(results).to include(party_with_weapon, party_with_character, empty_party)
      end
    end
  end

  describe 'count filters' do
    let!(:stacked_party) { create(:party, weapons_count: 10, characters_count: 5, summons_count: 4, visibility: 1) }
    let!(:light_party) { create(:party, weapons_count: 1, characters_count: 1, summons_count: 1, visibility: 1) }

    context 'with apply_defaults option' do
      let(:options) { { apply_defaults: true } }

      it 'filters parties by default count thresholds' do
        results = subject.build
        expect(results).to include(stacked_party)
        expect(results).not_to include(light_party)
      end
    end

    context 'with explicit count params' do
      let(:params) { { characters_count: '4' } }

      it 'filters parties by the specified count range' do
        results = subject.build
        expect(results).to include(stacked_party)
        expect(results).not_to include(light_party)
      end
    end

    context 'without count params or apply_defaults' do
      it 'does not filter by counts' do
        results = subject.build
        expect(results).to include(stacked_party, light_party)
      end
    end
  end

  describe 'private helper methods' do
    describe '#grid_table_and_object_table' do
      it 'maps 3xx IDs to characters' do
        expect(subject.send(:grid_table_and_object_table, '300001')).to eq(%w[grid_characters characters])
      end

      it 'maps 2xx IDs to summons' do
        expect(subject.send(:grid_table_and_object_table, '200001')).to eq(%w[grid_summons summons])
      end

      it 'maps 1xx IDs to weapons' do
        expect(subject.send(:grid_table_and_object_table, '100001')).to eq(%w[grid_weapons weapons])
      end

      it 'returns nil pair for unknown prefix' do
        expect(subject.send(:grid_table_and_object_table, '900001')).to eq([nil, nil])
      end
    end

    describe '#build_date_range' do
      let(:params) { { recency: '3600' } }

      it 'returns a range when recency is provided' do
        range = subject.send(:build_date_range)
        expect(range).to be_a(Range)
      end

      it 'returns nil when recency is missing' do
        builder = described_class.new(base_query, params: {}, current_user: current_user, options: options)
        expect(builder.send(:build_date_range)).to be_nil
      end
    end

    describe '#build_count' do
      it 'returns default when given blank' do
        expect(subject.send(:build_count, '', 3)).to eq(3)
      end

      it 'converts string to integer' do
        expect(subject.send(:build_count, '5', 3)).to eq(5)
      end
    end

    describe '#build_option' do
      it 'returns nil for blank' do
        expect(subject.send(:build_option, '')).to be_nil
      end

      it 'returns nil for -1' do
        expect(subject.send(:build_option, '-1')).to be_nil
      end

      it 'returns integer for valid input' do
        expect(subject.send(:build_option, '2')).to eq(2)
      end
    end
  end
end
