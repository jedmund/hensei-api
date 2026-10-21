# frozen_string_literal: true

require 'rails_helper'
require 'rake'

RSpec.describe CollectionArtifacts::RawDataClearer do
  let(:connection) { ActiveRecord::Base.connection }
  let!(:rows) { create_list(:collection_artifact, 5) }

  def store_payload(record)
    connection.exec_update(
      "UPDATE collection_artifacts SET raw_data = '{\"id\":\"1\"}'::jsonb WHERE id = #{connection.quote(record.id)}"
    )
  end

  def payload_count
    connection.select_value('SELECT count(*) FROM collection_artifacts WHERE raw_data IS NOT NULL')
  end

  before { rows.first(4).each { |row| store_payload(row) } }

  it 'clears every payload in batches and reports the count' do
    batches = []
    cleared = described_class.new(batch_size: 2).call { |batch, _total| batches << batch }

    expect(cleared).to eq(4)
    expect(batches).to eq([1, 2, 3])
    expect(payload_count).to eq(0)
  end

  it 'leaves the rest of the row alone' do
    before = CollectionArtifact.order(:id).pluck(:id, :level, :element, :updated_at)
    described_class.new(batch_size: 2).call

    expect(CollectionArtifact.order(:id).pluck(:id, :level, :element, :updated_at)).to eq(before)
  end

  it 'is a no-op on a second run and picks up payloads written since' do
    described_class.new.call
    expect(described_class.new.call).to eq(0)

    store_payload(rows.last)
    expect(described_class.new.call).to eq(1)
    expect(payload_count).to eq(0)
  end

  it 'handles an empty table' do
    CollectionArtifact.delete_all
    expect(described_class.new.call).to eq(0)
  end

  describe 'data migration' do
    let(:migration_class) do
      unless defined?(ClearCollectionArtifactRawData)
        require Rails.root.join('db/data/20261020150000_clear_collection_artifact_raw_data')
      end
      ClearCollectionArtifactRawData
    end

    it 'clears the payloads and can run again' do
      migration = migration_class.new.tap { |m| m.verbose = false }
      migration.up
      expect(payload_count).to eq(0)
      expect { migration.up }.not_to raise_error
    end

    it 'runs outside a transaction so each batch commits on its own' do
      expect(migration_class.new.disable_ddl_transaction).to be(true)
    end
  end

  describe 'rake collection_artifacts:clear_raw_data' do
    before(:all) do
      Rails.application.load_tasks if Rake::Task.tasks.none? { |t| t.name == 'collection_artifacts:clear_raw_data' }
    end

    after { Rake::Task['collection_artifacts:clear_raw_data'].reenable }

    it 'clears the payloads' do
      expect { Rake::Task['collection_artifacts:clear_raw_data'].invoke }
        .to output(/4 rows cleared/).to_stdout
      expect(payload_count).to eq(0)
    end
  end
end
