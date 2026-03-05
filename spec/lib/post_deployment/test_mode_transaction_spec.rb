# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PostDeployment::TestModeTransaction do
  subject(:transaction) { described_class.new }

  it 'starts with no changes' do
    expect(transaction.committed_changes).to be_empty
  end

  it 'records changes' do
    transaction.add_change(model: 'Character', attributes: { name_en: 'Zeta' }, operation: :create)
    transaction.add_change(model: 'Weapon', attributes: { name_en: 'Sword' }, operation: :update)

    expect(transaction.committed_changes.length).to eq(2)
    expect(transaction.committed_changes.first).to eq({
      model: 'Character', attributes: { name_en: 'Zeta' }, operation: :create
    })
  end

  it 'clears all changes on rollback' do
    transaction.add_change(model: 'Character', attributes: {}, operation: :create)
    transaction.rollback
    expect(transaction.committed_changes).to be_empty
  end

  it 'allows adding changes after rollback' do
    transaction.add_change(model: 'Weapon', attributes: {}, operation: :create)
    transaction.rollback
    transaction.add_change(model: 'Summon', attributes: {}, operation: :update)
    expect(transaction.committed_changes.length).to eq(1)
    expect(transaction.committed_changes.first[:model]).to eq('Summon')
  end
end
