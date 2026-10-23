# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'RemoveOrphanSources' do
  let(:migration_class) do
    require Rails.root.join('db/data/20261023100200_remove_orphan_sources') unless defined?(RemoveOrphanSources)
    RemoveOrphanSources
  end

  it 'removes rows whose owner is gone and keeps the rest, counting only' do
    kept = create(:summon, wiki_raw: '{{Kept}}')
    gone = create(:weapon, wiki_raw: '{{Gone}}')
    Weapon.where(id: gone.id).delete_all # SQL, so its rows stay behind
    Source.put(nil, :wiki_status_list, 'list', key: 'Module:StatusList')

    output = StringIO.new
    migration = migration_class.new
    allow(migration).to receive(:write) { |text| output.puts(text) }
    migration.up

    expect(Source.where(owner_id: gone.id)).to be_empty
    expect(Source.read(kept, :wiki_raw)).to eq('{{Kept}}')
    expect(Source.read(nil, :wiki_status_list, key: 'Module:StatusList')).to eq('list')
    expect(output.string).to include('Weapon: 1 orphan source rows removed', 'Summon: 0 orphan')
  end
end
