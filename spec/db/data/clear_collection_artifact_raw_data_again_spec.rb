# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'ClearCollectionArtifactRawDataAgain' do
  include ActiveJob::TestHelper

  let(:migration_class) do
    unless defined?(ClearCollectionArtifactRawDataAgain)
      require Rails.root.join('db/data/20261021180100_clear_collection_artifact_raw_data_again')
    end
    ClearCollectionArtifactRawDataAgain
  end

  def run
    output = StringIO.new
    migration = migration_class.new
    allow(migration).to receive(:write) { |text| output.puts(text) }
    migration.up
    output.string
  end

  def raw_data(artifact) = CollectionArtifact.unscoped.where(id: artifact.id).pick(:raw_data)

  it 'clears stored payloads in batches, logging counts only, and is a no-op after' do
    stub_const("#{migration_class}::BATCH", 1)
    with_payload = create_list(:collection_artifact, 2)
    without = create(:collection_artifact)
    CollectionArtifact.unscoped.where(id: with_payload.map(&:id)).update_all("raw_data = '{\"secret\":\"x\"}'::jsonb")

    output = nil
    expect { output = run }.not_to have_enqueued_job
    expect(output).to include('collection_artifacts.raw_data: 2 rows cleared')
    expect(output).not_to include('secret')
    expect((with_payload + [without]).map { |a| raw_data(a) }).to all(be_nil)

    expect(run).to include('collection_artifacts.raw_data: 0 rows cleared')
  end
end
