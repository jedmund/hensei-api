require 'rails_helper'

RSpec.describe SupportSummon, type: :model do
  describe 'associations' do
    it { should belong_to(:user) }
    it { should belong_to(:collection_summon) }
    it { should have_one(:summon).through(:collection_summon) }
  end

  describe 'enums' do
    it 'defines the seven sections' do
      expect(SupportSummon.sections.keys).to match_array(%w[wind fire water earth dark light misc])
    end

    it 'maps section integers to mirror the ELEMENTS enum plus misc' do
      expect(SupportSummon.sections).to eq(
        'wind' => 1, 'fire' => 2, 'water' => 3, 'earth' => 4, 'dark' => 5, 'light' => 6, 'misc' => 7
      )
    end
  end

  describe 'validations' do
    let(:user) { create(:user) }

    describe 'position bounds per section' do
      %w[wind fire water earth dark light].each do |section|
        context "#{section} section" do
          it 'accepts positions 0, 1, 2' do
            (0..2).each do |position|
              row = build(:support_summon, user: user, section: section, position: position)
              expect(row).to be_valid, "expected #{section}/#{position} to be valid"
            end
          end

          it 'rejects position 3' do
            row = build(:support_summon, user: user, section: section, position: 3)
            expect(row).not_to be_valid
            expect(row.errors[:position]).to be_present
          end

          it 'rejects negative positions' do
            row = build(:support_summon, user: user, section: section, position: -1)
            expect(row).not_to be_valid
          end
        end
      end

      context 'misc section' do
        it 'accepts positions 0, 1, 2, 3' do
          (0..3).each do |position|
            row = build(:support_summon, user: user, section: :misc, position: position)
            expect(row).to be_valid, "expected misc/#{position} to be valid"
          end
        end

        it 'rejects position 4' do
          row = build(:support_summon, user: user, section: :misc, position: 4)
          expect(row).not_to be_valid
          expect(row.errors[:position]).to be_present
        end
      end
    end

    describe 'uniqueness of (user, section, position)' do
      it 'is rejected at the model layer' do
        create(:support_summon, user: user, section: :fire, position: 0)
        duplicate = build(:support_summon, user: user, section: :fire, position: 0)
        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:position]).to include('has already been taken')
      end

      it 'allows the same position across different sections for one user' do
        create(:support_summon, user: user, section: :fire, position: 0)
        other = build(:support_summon, user: user, section: :water, position: 0)
        expect(other).to be_valid
      end

      it 'allows two different users to share the same slot' do
        other_user = create(:user)
        create(:support_summon, user: user, section: :fire, position: 0)
        other = build(:support_summon, user: other_user,
                                       collection_summon: create(:collection_summon, user: other_user),
                                       section: :fire,
                                       position: 0)
        expect(other).to be_valid
      end
    end

    describe 'collection_summon ownership' do
      it 'rejects a collection_summon owned by a different user' do
        other_user = create(:user)
        foreign_cs = create(:collection_summon, user: other_user)
        row = build(:support_summon, user: user, collection_summon: foreign_cs)
        expect(row).not_to be_valid
        expect(row.errors[:collection_summon]).to include('must belong to the same user')
      end
    end

    describe 'element / section independence' do
      it 'allows a Wind summon in the Fire section (strategic off-element placement)' do
        wind_summon = create(:summon, element: 1) # Wind
        wind_cs = create(:collection_summon, user: user, summon: wind_summon)
        row = build(:support_summon, user: user, collection_summon: wind_cs, section: :fire, position: 0)
        expect(row).to be_valid
      end

      it 'allows any element in the misc section' do
        light_summon = create(:summon, element: 6)
        light_cs = create(:collection_summon, user: user, summon: light_summon)
        row = build(:support_summon, user: user, collection_summon: light_cs, section: :misc, position: 3)
        expect(row).to be_valid
      end
    end
  end

  describe 'cascade deletes' do
    let(:user) { create(:user) }

    it 'is removed when its CollectionSummon is destroyed' do
      cs = create(:collection_summon, user: user)
      support = create(:support_summon, user: user, collection_summon: cs)
      expect { cs.destroy }.to change(SupportSummon, :count).by(-1)
      expect(SupportSummon.find_by(id: support.id)).to be_nil
    end

    it 'is removed when its User is destroyed' do
      create(:support_summon, user: user)
      expect { user.destroy }.to change(SupportSummon, :count).by(-1)
    end
  end

  describe 'scopes' do
    let(:user) { create(:user) }

    describe '.ordered' do
      it 'orders by section ascending, then position ascending' do
        misc0 = create(:support_summon, user: user, section: :misc, position: 0)
        fire2 = create(:support_summon, user: user, section: :fire, position: 2)
        fire0 = create(:support_summon, user: user, section: :fire, position: 0)
        wind1 = create(:support_summon, user: user, section: :wind, position: 1)

        expect(user.support_summons.ordered).to eq([wind1, fire0, fire2, misc0])
      end
    end

    describe '.by_section' do
      it 'returns only rows in the given section' do
        fire = create(:support_summon, user: user, section: :fire, position: 0)
        create(:support_summon, user: user, section: :water, position: 0)
        expect(SupportSummon.by_section(:fire)).to contain_exactly(fire)
      end
    end
  end
end
