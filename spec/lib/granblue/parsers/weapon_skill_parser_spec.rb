# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Granblue::Parsers::WeaponSkillParser do
  describe '.parse' do
    subject(:result) { described_class.parse(input) }

    # --- Blank / nil input ---

    context 'with nil input' do
      let(:input) { nil }

      it 'returns empty result' do
        expect(result).to eq(aura: nil, modifier: nil, series: nil, size: nil, skill_name: nil)
      end
    end

    context 'with empty string' do
      let(:input) { '' }

      it 'returns empty result' do
        expect(result).to eq(aura: nil, modifier: nil, series: nil, size: nil, skill_name: '')
      end
    end

    # --- HTML comment stripping ---

    context 'with HTML comments' do
      let(:input) { "Might II<!-- wiki note -->" }

      it 'strips comment and parses normally' do
        expect(result[:modifier]).to eq('Might')
        expect(result[:size]).to eq('medium')
      end

      it 'preserves original skill_name' do
        expect(result[:skill_name]).to eq(input)
      end
    end

    # --- Template syntax ---

    context 'with template syntax' do
      context '{{WeaponSkillMod|big normal}} Enmity' do
        let(:input) { '{{WeaponSkillMod|big normal}} Enmity' }

        it 'extracts modifier, series, and size' do
          aggregate_failures do
            expect(result[:modifier]).to eq('Enmity')
            expect(result[:series]).to eq('normal')
            expect(result[:size]).to eq('big')
            expect(result[:aura]).to be_nil
          end
        end
      end

      context '{{WeaponSkillMod|medium normal}} Might' do
        let(:input) { '{{WeaponSkillMod|medium normal}} Might' }

        it 'extracts medium size' do
          expect(result[:size]).to eq('medium')
        end
      end

      context '{{WeaponSkillMod|color}} Enmity' do
        let(:input) { '{{WeaponSkillMod|color}} Enmity' }

        it 'maps color to ex series with nil size' do
          aggregate_failures do
            expect(result[:series]).to eq('ex')
            expect(result[:size]).to be_nil
          end
        end
      end

      context '{{WeaponSkillMod|unique}} Supremacy' do
        let(:input) { '{{WeaponSkillMod|unique}} Supremacy' }

        it 'maps unique to nil series' do
          aggregate_failures do
            expect(result[:series]).to be_nil
            expect(result[:modifier]).to eq('Supremacy')
          end
        end
      end

      context 'preserves original skill_name' do
        let(:input) { '{{WeaponSkillMod|big normal}} Enmity' }

        it 'keeps the template string in skill_name' do
          expect(result[:skill_name]).to eq(input)
        end
      end
    end

    # --- Possessive format with known modifier ---

    context 'with possessive format and known modifier' do
      context 'normal series aura' do
        let(:input) { "Inferno's Might II" }

        it 'parses aura, modifier, series, and size' do
          aggregate_failures do
            expect(result[:aura]).to eq('Inferno')
            expect(result[:modifier]).to eq('Might')
            expect(result[:series]).to eq('normal')
            expect(result[:size]).to eq('medium')
          end
        end
      end

      context 'omega series aura' do
        let(:input) { "Ironflame's Enmity III" }

        it 'maps to omega series' do
          aggregate_failures do
            expect(result[:aura]).to eq('Ironflame')
            expect(result[:modifier]).to eq('Enmity')
            expect(result[:series]).to eq('omega')
            expect(result[:size]).to eq('big')
          end
        end
      end

      context 'ex series aura' do
        let(:input) { "Scarlet's Might II" }

        it 'maps to ex series' do
          expect(result[:series]).to eq('ex')
        end
      end

      context 'odious series aura (multi-word)' do
        let(:input) { "Taboo Doomfire's Enmity" }

        it 'maps multi-word aura to odious series' do
          aggregate_failures do
            expect(result[:aura]).to eq('Taboo Doomfire')
            expect(result[:modifier]).to eq('Enmity')
            expect(result[:series]).to eq('odious')
          end
        end
      end

      context 'no roman numeral' do
        let(:input) { "Oblivion's Might" }

        it 'returns nil size' do
          aggregate_failures do
            expect(result[:modifier]).to eq('Might')
            expect(result[:size]).to be_nil
          end
        end
      end
    end

    # --- Possessive format with known aura, unknown modifier ---

    context 'with possessive format and known aura but unknown modifier' do
      context 'Militis aura' do
        let(:input) { "Purgatory's Initiation" }

        it 'accepts the skill because aura is recognized' do
          aggregate_failures do
            expect(result[:aura]).to eq('Purgatory')
            expect(result[:modifier]).to eq('Initiation')
            expect(result[:series]).to be_nil
          end
        end
      end

      context 'CCW aura' do
        let(:input) { "Kengo's Essence" }

        it 'accepts the skill because aura is recognized' do
          aggregate_failures do
            expect(result[:aura]).to eq('Kengo')
            expect(result[:modifier]).to eq('Essence')
          end
        end
      end

      context 'Arcana aura (hyphenated)' do
        let(:input) { "Hierophant-Sun's Blessing" }

        it 'handles hyphenated aura names' do
          aggregate_failures do
            expect(result[:aura]).to eq('Hierophant-Sun')
            expect(result[:modifier]).to eq('Blessing')
          end
        end
      end
    end

    # --- Non-possessive multi-word modifier ---

    context 'with non-possessive multi-word modifier' do
      context 'odious aura + multi-word modifier' do
        let(:input) { 'Taboo Nightfall Supremacy: Decimation' }

        it 'splits aura and multi-word modifier' do
          aggregate_failures do
            expect(result[:aura]).to eq('Taboo Nightfall')
            expect(result[:modifier]).to eq('Supremacy: Decimation')
          end
        end
      end

      context 'short aura + multi-word modifier' do
        let(:input) { 'Fire Grand Epic' }

        it 'splits short aura from multi-word modifier' do
          aggregate_failures do
            expect(result[:aura]).to eq('Fire')
            expect(result[:modifier]).to eq('Grand Epic')
            expect(result[:series]).to eq('normal')
          end
        end
      end
    end

    # --- Non-possessive single-word modifier ---

    context 'with non-possessive single-word modifier' do
      context 'omega aura' do
        let(:input) { 'Ironflame Might III' }

        it 'parses aura, modifier, series, and size' do
          aggregate_failures do
            expect(result[:aura]).to eq('Ironflame')
            expect(result[:modifier]).to eq('Might')
            expect(result[:series]).to eq('omega')
            expect(result[:size]).to eq('big')
          end
        end
      end

      context 'normal aura' do
        let(:input) { 'Fire Might I' }

        it 'maps to normal series with small size' do
          aggregate_failures do
            expect(result[:aura]).to eq('Fire')
            expect(result[:series]).to eq('normal')
            expect(result[:size]).to eq('small')
          end
        end
      end
    end

    # --- Standalone modifier (no aura) ---

    context 'with standalone modifier' do
      context 'single-word with numeral' do
        let(:input) { 'Godblade I' }

        it 'returns modifier with nil aura' do
          aggregate_failures do
            expect(result[:aura]).to be_nil
            expect(result[:modifier]).to eq('Godblade')
            expect(result[:series]).to be_nil
            expect(result[:size]).to eq('small')
          end
        end
      end

      context 'multi-word standalone' do
        let(:input) { 'Scandere Aggressio' }

        it 'matches the full name as modifier' do
          aggregate_failures do
            expect(result[:modifier]).to eq('Scandere Aggressio')
            expect(result[:aura]).to be_nil
            expect(result[:size]).to be_nil
          end
        end
      end

      context 'Strike: Element (colon in modifier)' do
        let(:input) { 'Strike: Light' }

        it 'matches the full modifier including colon' do
          aggregate_failures do
            expect(result[:modifier]).to eq('Strike: Light')
            expect(result[:aura]).to be_nil
          end
        end
      end

      context 'Synchronized Artistry (special skill)' do
        let(:input) { 'Synchronized Artistry' }

        it 'recognizes as standalone modifier' do
          expect(result[:modifier]).to eq('Synchronized Artistry')
        end
      end

      context 'Greek letter modifier' do
        let(:input) { 'α Revelation' }

        it 'recognizes modifier with Greek letters' do
          aggregate_failures do
            expect(result[:modifier]).to eq('α Revelation')
            expect(result[:aura]).to be_nil
          end
        end
      end
    end

    # --- Sephira element normalization ---

    context 'with Sephira element-specific names' do
      context 'Tek pattern' do
        let(:input) { 'Sephira Fire-Tek' }

        it 'normalizes to Sephira Tek' do
          aggregate_failures do
            expect(result[:modifier]).to eq('Sephira Tek')
            expect(result[:aura]).to be_nil
            expect(result[:series]).to be_nil
          end
        end
      end

      context 'Tek pattern (different element)' do
        let(:input) { 'Sephira Dark-Tek' }

        it 'normalizes to Sephira Tek' do
          expect(result[:modifier]).to eq('Sephira Tek')
        end
      end

      context 'Soul pattern' do
        let(:input) { 'Sephira Windsoul' }

        it 'normalizes to Sephira Soul' do
          expect(result[:modifier]).to eq('Sephira Soul')
        end
      end

      context 'Soul pattern (different element)' do
        let(:input) { 'Sephira Firesoul' }

        it 'normalizes to Sephira Soul' do
          expect(result[:modifier]).to eq('Sephira Soul')
        end
      end

      context 'Legio sub-pattern' do
        let(:input) { 'Sephira Legio Ventus' }

        it 'normalizes to Sephira Legio' do
          expect(result[:modifier]).to eq('Sephira Legio')
        end
      end

      context 'Manus sub-pattern' do
        let(:input) { 'Sephira Manus Terra' }

        it 'normalizes to Sephira Manus' do
          expect(result[:modifier]).to eq('Sephira Manus')
        end
      end

      context 'Salire sub-pattern' do
        let(:input) { 'Sephira Salire Lux' }

        it 'normalizes to Sephira Salire' do
          expect(result[:modifier]).to eq('Sephira Salire')
        end
      end

      context 'Telum sub-pattern' do
        let(:input) { 'Sephira Telum Ignis' }

        it 'normalizes to Sephira Telum' do
          expect(result[:modifier]).to eq('Sephira Telum')
        end
      end
    end

    # --- Element-specific Exalto ---

    context 'with element-specific Exalto' do
      context 'Omega Exalto' do
        let(:input) { 'Omega Exalto Caliginis' }

        it 'normalizes to Omega Exalto with omega series' do
          aggregate_failures do
            expect(result[:modifier]).to eq('Omega Exalto')
            expect(result[:series]).to eq('omega')
            expect(result[:aura]).to be_nil
          end
        end
      end

      context 'Omega Exalto (different element)' do
        let(:input) { 'Omega Exalto Luminis' }

        it 'normalizes to Omega Exalto with omega series' do
          expect(result[:modifier]).to eq('Omega Exalto')
          expect(result[:series]).to eq('omega')
        end
      end

      context 'Optimus Exalto' do
        let(:input) { 'Optimus Exalto Terrae' }

        it 'normalizes to Optimus Exalto with normal series' do
          aggregate_failures do
            expect(result[:modifier]).to eq('Optimus Exalto')
            expect(result[:series]).to eq('normal')
            expect(result[:aura]).to be_nil
          end
        end
      end

      context 'Optimus Exalto (different element)' do
        let(:input) { 'Optimus Exalto Ardendi' }

        it 'normalizes to Optimus Exalto with normal series' do
          expect(result[:modifier]).to eq('Optimus Exalto')
          expect(result[:series]).to eq('normal')
        end
      end
    end

    # --- Element-specific Preemptive ---

    context 'with element-specific Preemptive' do
      context 'Preemptive Fire Blade' do
        let(:input) { 'Preemptive Fire Blade' }

        it 'strips element word and normalizes to Preemptive Blade' do
          aggregate_failures do
            expect(result[:modifier]).to eq('Preemptive Blade')
            expect(result[:series]).to be_nil
            expect(result[:aura]).to be_nil
          end
        end
      end

      context 'Preemptive Ice Wall' do
        let(:input) { 'Preemptive Ice Wall' }

        it 'normalizes to Preemptive Wall' do
          expect(result[:modifier]).to eq('Preemptive Wall')
        end
      end

      context 'Preemptive Shadow Barrier' do
        let(:input) { 'Preemptive Shadow Barrier' }

        it 'normalizes to Preemptive Barrier' do
          expect(result[:modifier]).to eq('Preemptive Barrier')
        end
      end
    end

    # --- Element-suffixed modifiers ---

    context 'with element-suffixed modifiers' do
      context 'Clawed' do
        let(:input) { 'Clawed Shadow' }

        it 'strips element word' do
          aggregate_failures do
            expect(result[:modifier]).to eq('Clawed')
            expect(result[:series]).to be_nil
            expect(result[:aura]).to be_nil
          end
        end
      end

      context 'Armed' do
        let(:input) { 'Armed Gale' }

        it 'strips element word' do
          expect(result[:modifier]).to eq('Armed')
        end
      end

      context 'Resilient' do
        let(:input) { 'Resilient Shine' }

        it 'strips element word' do
          expect(result[:modifier]).to eq('Resilient')
        end
      end

      context 'Willed' do
        let(:input) { 'Willed Flood' }

        it 'strips element word' do
          expect(result[:modifier]).to eq('Willed')
        end
      end
    end

    # --- Roman numeral sizes ---

    context 'with roman numeral sizes' do
      {
        'I' => 'small',
        'II' => 'medium',
        'III' => 'big',
        'IV' => 'massive',
        'V' => 'massive'
      }.each do |numeral, expected_size|
        context "numeral #{numeral}" do
          let(:input) { "Might #{numeral}" }

          it "maps to #{expected_size}" do
            expect(result[:size]).to eq(expected_size)
          end
        end
      end

      context 'no numeral' do
        let(:input) { 'Might' }

        it 'returns nil size' do
          expect(result[:size]).to be_nil
        end
      end
    end

    # --- Unrecognized skills ---

    context 'with unrecognized skill' do
      let(:input) { 'Tuna Toss' }

      it 'returns all nil except skill_name' do
        aggregate_failures do
          expect(result[:aura]).to be_nil
          expect(result[:modifier]).to be_nil
          expect(result[:series]).to be_nil
          expect(result[:size]).to be_nil
          expect(result[:skill_name]).to eq('Tuna Toss')
        end
      end
    end

    context 'with another unrecognized skill' do
      let(:input) { 'Super Abomideath Power Z' }

      it 'returns all nil except skill_name' do
        expect(result[:modifier]).to be_nil
        expect(result[:skill_name]).to eq(input)
      end
    end
  end
end
