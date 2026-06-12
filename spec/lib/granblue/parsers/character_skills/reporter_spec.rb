# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Granblue::Parsers::CharacterSkills::Reporter do
  let(:data) { instance_double(Granblue::Parsers::CharacterWikiData) }
  let(:status) { instance_double(Status, game_ailment_id: '111') }
  let(:status_lookup) { { by_name: {}, by_id: { 's1' => status } } }

  subject(:reporter) { described_class.new(data: data, status_lookup: status_lookup) }

  let(:graph) do
    {
      character_granblue_id: '3040000000',
      slots: [
        { attrs: { kind: 'ability', position: 1 },
          versions: [
            { source_key: 'a1', attrs: { name_en: 'Skill' }, effects: [{ status_id: 's1' }, { status_id: nil }] }
          ] }
      ],
      links: [{ from_version_key: 'x', to_version_key: 'y', relation: 'transforms_to' }]
    }
  end

  it 'reports counts and sorted unmatched statuses' do
    allow(data).to receive(:game_action).with('a1').and_return({ 'ailment' => '111' })
    allow(data).to receive(:csv).with('111').and_return(['111'])

    report = reporter.report_for(graph, unmatched_statuses: Set['Zed', 'Alpha'])

    aggregate_failures do
      expect(report[:character_granblue_id]).to eq('3040000000')
      expect(report[:counts]).to eq(slots: 1, versions: 1, effects: 2, links: 1)
      expect(report[:unmatched_statuses]).to eq(%w[Alpha Zed])
      expect(report[:cross_validation]).to be_empty
    end
  end

  it 'flags game ailment ids that were not parsed as statuses' do
    allow(data).to receive(:game_action).with('a1').and_return({ 'ailment' => '111,222' })
    allow(data).to receive(:csv).with('111,222').and_return(%w[111 222])

    gap = reporter.report_for(graph, unmatched_statuses: Set.new)[:cross_validation].first

    expect(gap).to include(version: 'Skill', missing_game_ailment_ids: ['222'])
  end
end
