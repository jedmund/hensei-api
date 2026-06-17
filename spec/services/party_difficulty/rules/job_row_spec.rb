# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PartyDifficulty::Rules::JobRow do
  let(:rule) { described_class.new('rows' => ['4'], 'requires_ultimate_mastery' => true) }
  let(:job) { build_stubbed(:job, row: '4') }

  it 'matches when the party has a positive ultimate mastery level' do
    party = build_stubbed(:party, job: job, ultimate_mastery_level: 1)

    expect(rule).to be_applies(party)
  end

  it 'does not match when the ultimate mastery level is unset or zero' do
    expect(rule).not_to be_applies(build_stubbed(:party, job: job, ultimate_mastery_level: nil))
    expect(rule).not_to be_applies(build_stubbed(:party, job: job, ultimate_mastery_level: 0))
  end
end
