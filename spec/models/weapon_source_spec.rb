# frozen_string_literal: true

require 'rails_helper'

# The weapon-skill store's rows of `sources` (PR 7b).
RSpec.describe WeaponSource do
  let(:weapon) { create(:weapon, wiki_raw: '{{Own page}}') }

  it 'stores rows in sources, owned by the weapon or shared' do
    owned = described_class.create!(weapon: weapon, kind: 'wiki_raw', key: 'Blade', body: '{{Weapon}}',
                                    fetched_at: Time.current, page_kind: 'inline')
    shared = described_class.create!(kind: 'family_template', key: 'Template:Weapon Skills/Might', body: 'family',
                                     fetched_at: Time.current)

    expect(Source.find(owned.id)).to have_attributes(owner_type: 'Weapon', owner_id: weapon.id, key: 'Blade',
                                                     sha256: Digest::SHA256.hexdigest('{{Weapon}}'))
    expect(Source.find(shared.id)).to have_attributes(owner_type: nil, owner_id: nil)
    expect(owned.weapon_id).to eq(weapon.id)
    expect(owned.weapon).to eq(weapon)
  end

  it "leaves out the weapon's own wiki_raw and other owners' rows" do
    character = Character.without_skill_build { create(:character, wiki_raw: '{{Character}}') }
    Source.put(nil, :wiki_status_list, 'list', key: 'Module:StatusList')
    described_class.create!(weapon: weapon, kind: 'wiki_raw', key: 'Blade', body: '{{Weapon}}', fetched_at: Time.current)

    expect(described_class.pluck(:key)).to eq(['Blade'])
    expect(described_class.where(weapon_id: weapon.id).count).to eq(1)
    expect(Source.owned_by(character).count).to eq(1)
    expect(Source.read(weapon, :wiki_raw)).to eq('{{Own page}}')
  end
end
