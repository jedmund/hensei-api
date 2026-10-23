# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'FlagSummonsWithSubAuras' do
  let(:migration_class) do
    require Rails.root.join('db/data/20261023200000_flag_summons_with_sub_auras') unless defined?(FlagSummonsWithSubAuras)
    FlagSummonsWithSubAuras
  end

  def run
    migration_class.new.tap { |m| m.verbose = false }.up
  end

  def summon(subaura:, sub_rows:)
    Summon.without_aura_build { create(:summon, subaura: subaura) }.tap do |s|
      create(:summon_aura, summon_granblue_id: s.granblue_id, slot: 'main', target: 'other')
      create(:summon_aura, summon_granblue_id: s.granblue_id, slot: 'sub', target: 'other') if sub_rows
    end
  end

  it 'flags summons with sub-aura rows and leaves the rest alone' do
    missing = summon(subaura: false, sub_rows: true)
    main_only = summon(subaura: false, sub_rows: false)
    flagged_without_rows = summon(subaura: true, sub_rows: false)

    run

    expect(missing.reload.subaura).to be(true)
    expect(main_only.reload.subaura).to be(false)
    expect(flagged_without_rows.reload.subaura).to be(true)
  end

  it 'is a no-op on a second run' do
    summon(subaura: false, sub_rows: true)
    run
    migration = migration_class.new.tap { |m| m.verbose = false }
    allow(migration).to receive(:say)
    migration.up
    expect(migration).to have_received(:say).with('flagged 0 summons with sub auras: ')
  end
end
