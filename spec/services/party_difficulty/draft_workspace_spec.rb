# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PartyDifficulty::DraftWorkspace do
  let(:user) { create(:user) }
  let(:component) do
    DifficultyComponent.find_or_create_by!(name: 'weapon') do |c|
      c.weight = 1
      c.enabled = true
      c.min_count_to_score = 0
    end
  end
  let!(:rule) do
    DifficultyRule.create!(
      name: 'Spec base rule', component: 'weapon', rule_type: 'weapon_uncap_at_least',
      weight: 2.0, active: true,
      params: { 'min_uncap_level' => 1, 'min_count' => 1 }
    )
  end
  let!(:tier) do
    Difficulty.find_or_create_by!(slug: 'spec-tier') do |t|
      t.name = 'Spec'
      t.min_score = 0
      t.max_score = 100
      t.sort_order = 99
    end
  end

  subject(:workspace) { described_class.for(user) }

  describe '#stage!' do
    it 'creates an update draft and surfaces it in merged_rules with pending? true' do
      workspace.stage!(
        target_type: 'DifficultyRule', target_id: rule.id, operation: 'update',
        attributes: { weight: 99.0 }
      )

      reloaded = described_class.for(user)
      merged = reloaded.merged_rules.find { |r| r.id == rule.id }
      expect(merged.weight.to_f).to eq(99.0)
      expect(merged.pending?).to be(true)
      expect(merged.pending_operation).to eq('update')
    end

    it 'is idempotent on (user, target_type, target_id) for updates' do
      workspace.stage!(target_type: 'DifficultyRule', target_id: rule.id, operation: 'update', attributes: { weight: 5 })
      workspace.stage!(target_type: 'DifficultyRule', target_id: rule.id, operation: 'update', attributes: { weight: 6 })

      expect(DifficultyDraft.for_user(user).where(target_id: rule.id).count).to eq(1)
      expect(DifficultyDraft.for_user(user).find_by(target_id: rule.id).attributes_payload['weight']).to eq(6)
    end

    it 'records a destroy and omits the row from merged_rules' do
      workspace.stage!(target_type: 'DifficultyRule', target_id: rule.id, operation: 'destroy', attributes: {})

      reloaded = described_class.for(user)
      expect(reloaded.merged_rules.map(&:id)).not_to include(rule.id)
    end

    it 'accepts ActionController::Parameters from controllers' do
      params = ActionController::Parameters.new(name: 'Hard', sort_order: 5).permit(:name, :sort_order)

      draft = workspace.stage!(
        target_type: 'Difficulty', target_id: nil,
        operation: 'create', attributes: params
      )

      expect(draft.attributes_payload).to eq('name' => 'Hard', 'sort_order' => 5)
    end
  end

  describe '#diff' do
    it 'reports field-level old/new for an update' do
      workspace.stage!(target_type: 'DifficultyRule', target_id: rule.id, operation: 'update', attributes: { weight: 7.5 })

      diff = described_class.for(user).diff
      change = diff[:rules][:updates].first
      expect(change[:changes]['weight']).to include(new: 7.5)
    end

    it 'batch-loads targets per section instead of one query per draft' do
      extra_rules = Array.new(3) do |i|
        DifficultyRule.create!(
          name: "Spec rule #{i}", component: 'weapon', rule_type: 'weapon_uncap_at_least',
          weight: 1.0, active: true,
          params: { 'min_uncap_level' => 1, 'min_count' => 1 }
        )
      end
      [rule, *extra_rules].each_with_index do |r, i|
        workspace.stage!(target_type: 'DifficultyRule', target_id: r.id, operation: 'update', attributes: { weight: i + 10.0 })
      end

      reloaded = described_class.for(user)
      rule_loads = 0
      subscriber = ActiveSupport::Notifications.subscribe('sql.active_record') do |_, _, _, _, payload|
        next if payload[:name] == 'SCHEMA' || payload[:cached]
        rule_loads += 1 if payload[:sql].include?('FROM "difficulty_rules"')
      end
      begin
        reloaded.diff
      ensure
        ActiveSupport::Notifications.unsubscribe(subscriber)
      end

      expect(rule_loads).to eq(1)
    end
  end

  describe '#commit!' do
    it 'promotes drafts to canonical, bumps the ruleset version, writes a log, and clears drafts' do
      workspace.stage!(target_type: 'DifficultyRule', target_id: rule.id, operation: 'update', attributes: { weight: 12.0 })
      starting_version = DifficultyConfig.current_version

      log = described_class.for(user).commit!(note: 'spec')

      rule.reload
      expect(rule.weight.to_f).to eq(12.0)
      expect(log.note).to eq('spec')
      expect(log.ruleset_version_after).to be > starting_version
      expect(DifficultyDraft.for_user(user).count).to eq(0)
    end

    context 'with multi-tier score boundary edits' do
      # Seed a 4-tier layout that already tiles [0, 100] so we can stage edits
      # against it. Seeding requires bypassing the per-row coverage check
      # because no insertion order is individually valid against an empty DB.
      let!(:tiers) do
        Difficulty.delete_all
        Difficulty.with_coverage_validation_skipped do
          [
            Difficulty.create!(name: 'Beginner', slug: 'beginner', min_score: 0.0, max_score: 24.99, sort_order: 0),
            Difficulty.create!(name: 'Intermediate', slug: 'intermediate', min_score: 25.0, max_score: 49.99, sort_order: 1),
            Difficulty.create!(name: 'Advanced', slug: 'advanced', min_score: 50.0, max_score: 84.99, sort_order: 2),
            Difficulty.create!(name: 'Whale', slug: 'whale', min_score: 85.0, max_score: 100.0, sort_order: 3)
          ]
        end
      end

      it 'commits a valid multi-tier rebalance whose intermediate states would individually fail' do
        intermediate = tiers[1]
        advanced = tiers[2]
        workspace.stage!(target_type: 'Difficulty', target_id: intermediate.id, operation: 'update',
                         attributes: { max_score: 59.99 })
        workspace.stage!(target_type: 'Difficulty', target_id: advanced.id, operation: 'update',
                         attributes: { min_score: 60.0 })

        described_class.for(user).commit!(note: 'rebalance')

        expect(intermediate.reload.max_score.to_f).to eq(59.99)
        expect(advanced.reload.min_score.to_f).to eq(60.0)
      end

      it 'raises CoverageError and rolls back when the final tier set has a real gap' do
        intermediate = tiers[1]
        workspace.stage!(target_type: 'Difficulty', target_id: intermediate.id, operation: 'update',
                         attributes: { max_score: 40.0 })

        expect do
          described_class.for(user).commit!(note: 'broken')
        end.to raise_error(PartyDifficulty::CoverageError, /coverage gap/)

        expect(intermediate.reload.max_score.to_f).to eq(49.99)
      end

      it 'raises CoverageError when a staged draft inverts a tier bounds (max <= min)' do
        intermediate = tiers[1]
        workspace.stage!(target_type: 'Difficulty', target_id: intermediate.id, operation: 'update',
                         attributes: { min_score: 60.0, max_score: 50.0 })

        expect do
          described_class.for(user).commit!(note: 'inverted')
        end.to raise_error(PartyDifficulty::CoverageError, /max_score not greater than min_score/)

        expect(intermediate.reload.min_score.to_f).to eq(25.0)
        expect(intermediate.reload.max_score.to_f).to eq(49.99)
      end
    end
  end

  describe 'Difficulty.with_coverage_validation_skipped' do
    let(:bad_tier) do
      Difficulty.new(name: 'Bad', slug: 'bad', min_score: 0.0, max_score: 5.0, sort_order: 50)
    end

    it 'suppresses the per-row coverage check inside the block' do
      Difficulty.with_coverage_validation_skipped do
        expect(bad_tier).to be_valid
      end
    end

    it 'restores per-row coverage validation after the block exits' do
      Difficulty.with_coverage_validation_skipped { :noop }
      expect(bad_tier).not_to be_valid
      expect(bad_tier.errors[:base].join).to include('coverage')
    end

    it 'restores the flag even if the block raises' do
      expect { Difficulty.with_coverage_validation_skipped { raise 'boom' } }.to raise_error('boom')
      expect(Thread.current[:difficulty_skip_coverage_validation]).to be_falsey
      expect(bad_tier).not_to be_valid
    end
  end

  describe '#discard!' do
    it 'wipes the user drafts' do
      workspace.stage!(target_type: 'DifficultyRule', target_id: rule.id, operation: 'update', attributes: { weight: 1 })
      expect { described_class.for(user).discard! }.to change { DifficultyDraft.for_user(user).count }.to(0)
    end
  end

  describe '#attach_image!' do
    # 1x1 transparent PNG, base64-encoded — passes signature + dimension checks.
    let(:png_base64) do
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII='
    end

    before do
      allow(IconStorage).to receive(:put)
      allow(IconStorage).to receive(:copy)
      allow(IconStorage).to receive(:delete)
    end

    it 'stages the upload at the draft-scoped key and records image_key on attributes' do
      draft = workspace.stage!(
        target_type: 'Difficulty', target_id: tier.id, operation: 'update', attributes: { name: 'Renamed' }
      )

      workspace.attach_image!(draft, image_data: png_base64, filename: 'tier.png')

      expected_key = "images/difficulties/_drafts/#{draft.id}.png"
      expect(IconStorage).to have_received(:put).with(expected_key, kind_of(String))
      expect(draft.reload.attributes_payload['image_key']).to eq(expected_key)
      expect(draft.attributes_payload['image_filename']).to eq('tier.png')
    end

    it 'raises an ImageValidationError when bytes are not a PNG' do
      draft = workspace.stage!(
        target_type: 'Difficulty', target_id: tier.id, operation: 'update', attributes: { name: 'x' }
      )
      junk = Base64.strict_encode64('not an image')

      expect { workspace.attach_image!(draft, image_data: junk) }
        .to raise_error(described_class::ImageValidationError, /PNG/)
    end
  end

  describe '#commit! with staged image' do
    let(:png_base64) do
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII='
    end

    before do
      allow(IconStorage).to receive(:put)
      allow(IconStorage).to receive(:copy)
      allow(IconStorage).to receive(:delete)
    end

    it 'promotes the staged image to the canonical key and writes image_key on the tier' do
      draft = workspace.stage!(
        target_type: 'Difficulty', target_id: tier.id, operation: 'update', attributes: { name: 'New' }
      )
      workspace.attach_image!(draft, image_data: png_base64)
      staged_key = "images/difficulties/_drafts/#{draft.id}.png"
      final_key = "images/difficulties/#{tier.id}.png"

      described_class.for(user).commit!

      expect(IconStorage).to have_received(:copy).with(staged_key, final_key)
      expect(IconStorage).to have_received(:delete).with(staged_key)
      expect(tier.reload.image_key).to eq(final_key)
    end
  end

  describe '#discard! with staged image' do
    let(:png_base64) do
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII='
    end

    before do
      allow(IconStorage).to receive(:put)
      allow(IconStorage).to receive(:delete)
    end

    it 'removes temp images from storage' do
      draft = workspace.stage!(
        target_type: 'Difficulty', target_id: tier.id, operation: 'update', attributes: { name: 'x' }
      )
      workspace.attach_image!(draft, image_data: png_base64)
      staged_key = "images/difficulties/_drafts/#{draft.id}.png"

      described_class.for(user).discard!

      expect(IconStorage).to have_received(:delete).with(staged_key)
    end
  end
end
