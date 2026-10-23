# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Sources::OrphanCleanup do
  it "removes orphan rows and a weapon's untitled page beside its titled one" do
    gone = create(:summon, wiki_raw: '{{Gone}}')
    Summon.where(id: gone.id).delete_all
    weapon = create(:weapon, wiki_en: 'Blade', wiki_raw: '{{Own}}')
    WeaponSource.create!(weapon: weapon, kind: 'wiki_raw', key: 'Blade', body: '{{Own}}', fetched_at: Time.current)
    lone = create(:weapon, wiki_raw: '{{Lone}}')

    expect(described_class.new.call).to include('Summon' => 1, 'Weapon untitled pages' => 1)
    expect(Source.owned_by(weapon).pluck(:key)).to eq(['Blade'])
    expect(Source.read(lone, :wiki_raw)).to eq('{{Lone}}')
  end
end
