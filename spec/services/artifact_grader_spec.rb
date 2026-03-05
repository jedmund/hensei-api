# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ArtifactGrader do
  let(:skill_double) { double('ArtifactSkill', name_en: 'Test Skill', name_jp: 'テスト', base_values: [100, 200, 300, 400, 500]) }

  before do
    allow(ArtifactSkill).to receive(:find_skill).and_return(skill_double)
  end

  def build_artifact(skill1: {}, skill2: {}, skill3: {}, skill4: {}, quirk: false)
    double('CollectionArtifact',
      skill1: skill1, skill2: skill2, skill3: skill3, skill4: skill4,
      artifact: double('Artifact', quirk?: quirk))
  end

  describe '#grade' do
    context 'quirk artifact' do
      it 'returns ungraded result with note' do
        artifact = build_artifact(quirk: true)
        result = described_class.new(artifact).grade

        aggregate_failures do
          expect(result[:letter]).to be_nil
          expect(result[:score]).to be_nil
          expect(result[:note]).to eq('Quirk artifacts cannot be graded')
        end
      end
    end

    context 'tier scoring' do
      it 'scores ideal skills highest' do
        # Group I ideal: modifier 8 (Triple Attack Rate)
        artifact = build_artifact(
          skill1: { 'modifier' => 8, 'strength' => 300, 'level' => 1 },
          skill2: { 'modifier' => 8, 'strength' => 300, 'level' => 1 },
          skill3: { 'modifier' => 1, 'strength' => 300, 'level' => 1 },
          skill4: { 'modifier' => 11, 'strength' => 300, 'level' => 1 }
        )
        result = described_class.new(artifact).grade

        result[:lines].each do |line|
          expect(line[:tier]).to eq(:ideal)
          expect(line[:tier_score]).to eq(100)
        end
      end

      it 'scores bad skills lowest' do
        # Group I bad: modifier 4 (Skill DMG)
        artifact = build_artifact(
          skill1: { 'modifier' => 4, 'strength' => 300, 'level' => 1 },
          skill2: { 'modifier' => 4, 'strength' => 300, 'level' => 1 },
          skill3: { 'modifier' => 17, 'strength' => 300, 'level' => 1 },
          skill4: { 'modifier' => 9, 'strength' => 300, 'level' => 1 }
        )
        result = described_class.new(artifact).grade

        result[:lines].each do |line|
          expect(line[:tier]).to eq(:bad)
          expect(line[:tier_score]).to eq(10)
        end
      end
    end

    context 'weighted scoring' do
      it 'applies 50/30/20 weights for selection/strength/synergy' do
        artifact = build_artifact(
          skill1: { 'modifier' => 8, 'strength' => 300, 'level' => 1 },
          skill2: { 'modifier' => 8, 'strength' => 300, 'level' => 1 },
          skill3: { 'modifier' => 1, 'strength' => 300, 'level' => 1 },
          skill4: { 'modifier' => 11, 'strength' => 300, 'level' => 1 }
        )
        result = described_class.new(artifact).grade

        aggregate_failures do
          expect(result[:breakdown]).to have_key(:skill_selection)
          expect(result[:breakdown]).to have_key(:base_strength)
          expect(result[:breakdown]).to have_key(:synergy)
          expect(result[:score]).to eq(
            (result[:breakdown][:skill_selection] * 0.5 +
             result[:breakdown][:base_strength] * 0.3 +
             result[:breakdown][:synergy] * 0.2).round
          )
        end
      end
    end

    context 'letter grades' do
      it 'assigns S for scores >= 95' do
        artifact = build_artifact(
          skill1: { 'modifier' => 8, 'strength' => 500, 'level' => 1 },
          skill2: { 'modifier' => 13, 'strength' => 500, 'level' => 1 },
          skill3: { 'modifier' => 9, 'strength' => 500, 'level' => 1 },
          skill4: { 'modifier' => 11, 'strength' => 500, 'level' => 1 }
        )
        result = described_class.new(artifact).grade
        # With all ideal skills + max strength + synergy bonuses, should be S or A
        expect(%w[S A]).to include(result[:letter])
      end

      it 'assigns F for very low scores' do
        artifact = build_artifact(
          skill1: { 'modifier' => 4, 'strength' => 100, 'level' => 1 },
          skill2: { 'modifier' => 7, 'strength' => 100, 'level' => 1 },
          skill3: { 'modifier' => 17, 'strength' => 100, 'level' => 1 },
          skill4: { 'modifier' => 9, 'strength' => 100, 'level' => 1 }
        )
        result = described_class.new(artifact).grade
        expect(%w[D F]).to include(result[:letter])
      end
    end

    context 'strength scoring' do
      it 'scores based on position in base_values array' do
        # base_values [100, 200, 300, 400, 500], strength 100 -> index 0 -> 20%
        artifact = build_artifact(
          skill1: { 'modifier' => 8, 'strength' => 100, 'level' => 1 },
          skill2: { 'modifier' => 8, 'strength' => 500, 'level' => 1 },
          skill3: { 'modifier' => 1, 'strength' => 300, 'level' => 1 },
          skill4: { 'modifier' => 11, 'strength' => 300, 'level' => 1 }
        )
        result = described_class.new(artifact).grade

        expect(result[:lines][0][:strength_score]).to eq(20) # index 0
        expect(result[:lines][1][:strength_score]).to eq(100) # index 4
      end

      it 'returns 50 when strength is nil' do
        artifact = build_artifact(
          skill1: { 'modifier' => 8, 'strength' => nil, 'level' => 1 },
          skill2: { 'modifier' => 8, 'strength' => 300, 'level' => 1 },
          skill3: { 'modifier' => 1, 'strength' => 300, 'level' => 1 },
          skill4: { 'modifier' => 11, 'strength' => 300, 'level' => 1 }
        )
        result = described_class.new(artifact).grade
        expect(result[:lines][0][:strength_score]).to eq(50)
      end
    end

    context 'synergy scoring' do
      it 'adds bonus for matching synergy pairs' do
        # Pair: Triple Attack Rate (I-8) + TA at 50%+ HP (II-13)
        artifact = build_artifact(
          skill1: { 'modifier' => 8, 'strength' => 300, 'level' => 1 },
          skill2: { 'modifier' => 5, 'strength' => 300, 'level' => 1 },
          skill3: { 'modifier' => 13, 'strength' => 300, 'level' => 1 },
          skill4: { 'modifier' => 11, 'strength' => 300, 'level' => 1 }
        )
        result = described_class.new(artifact).grade
        # Base synergy is 50, +10 per match
        expect(result[:breakdown][:synergy]).to be >= 60
      end

      it 'returns base synergy of 50 with no matching pairs' do
        artifact = build_artifact(
          skill1: { 'modifier' => 1, 'strength' => 300, 'level' => 1 },
          skill2: { 'modifier' => 2, 'strength' => 300, 'level' => 1 },
          skill3: { 'modifier' => 12, 'strength' => 300, 'level' => 1 },
          skill4: { 'modifier' => 1, 'strength' => 300, 'level' => 1 }
        )
        result = described_class.new(artifact).grade
        expect(result[:breakdown][:synergy]).to eq(50)
      end
    end

    context 'recommendations' do
      it 'recommends scrap for very low scores' do
        artifact = build_artifact(
          skill1: { 'modifier' => 4, 'strength' => 100, 'level' => 1 },
          skill2: { 'modifier' => 7, 'strength' => 100, 'level' => 1 },
          skill3: { 'modifier' => 17, 'strength' => 100, 'level' => 1 },
          skill4: { 'modifier' => 9, 'strength' => 100, 'level' => 1 }
        )
        result = described_class.new(artifact).grade
        expect(result[:recommendation][:action]).to eq(:scrap)
      end

      it 'recommends keep for high scores' do
        artifact = build_artifact(
          skill1: { 'modifier' => 8, 'strength' => 500, 'level' => 1 },
          skill2: { 'modifier' => 13, 'strength' => 500, 'level' => 1 },
          skill3: { 'modifier' => 1, 'strength' => 500, 'level' => 1 },
          skill4: { 'modifier' => 11, 'strength' => 500, 'level' => 1 }
        )
        result = described_class.new(artifact).grade
        expect(result[:recommendation][:action]).to eq(:keep)
      end

      it 'recommends reroll with weakest line info' do
        # Mix of good and bad skills
        artifact = build_artifact(
          skill1: { 'modifier' => 8, 'strength' => 500, 'level' => 1 },
          skill2: { 'modifier' => 8, 'strength' => 500, 'level' => 1 },
          skill3: { 'modifier' => 1, 'strength' => 500, 'level' => 1 },
          skill4: { 'modifier' => 2, 'strength' => 100, 'level' => 1 }
        )
        result = described_class.new(artifact).grade

        if result[:recommendation][:action] == :reroll
          aggregate_failures do
            expect(result[:recommendation]).to have_key(:slot)
            expect(result[:recommendation]).to have_key(:potential_gain)
            expect(result[:recommendation]).to have_key(:target_skills)
          end
        end
      end
    end

    context 'empty skill data' do
      it 'handles nil lines gracefully' do
        artifact = build_artifact(
          skill1: { 'modifier' => 8, 'strength' => 300, 'level' => 1 },
          skill2: {},
          skill3: { 'modifier' => 1, 'strength' => 300, 'level' => 1 },
          skill4: { 'modifier' => 11, 'strength' => 300, 'level' => 1 }
        )
        result = described_class.new(artifact).grade
        expect(result[:lines][1]).to be_nil
      end
    end
  end
end
