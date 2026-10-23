# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Granblue::Parsers::CharacterSkills::Reporter do
  subject(:reporter) { described_class.new }

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
    report = reporter.report_for(graph, unmatched_statuses: Set['Zed', 'Alpha'])

    aggregate_failures do
      expect(report[:character_granblue_id]).to eq('3040000000')
      expect(report[:counts]).to eq(slots: 1, versions: 1, effects: 2, links: 1)
      expect(report[:unmatched_statuses]).to eq(%w[Alpha Zed])
    end
  end
end
