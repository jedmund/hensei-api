require 'rails_helper'
require Rails.root.join('db/data/20261110120000_set_exclusive_avatars')

RSpec.describe SetExclusiveAvatars do
  subject(:migration) { described_class.new }

  it 'gives each owning account its picture and leaves everyone else alone, rerunnably' do
    umikin = create(:user, id: User::EXCLUSIVE_PICTURES['custom_umikin'], picture: 'gran')
    jedmund = create(:user, id: User::EXCLUSIVE_PICTURES['custom_jedmund'], picture: 'zeta')
    namesake = create(:user, username: 'reverie', picture: 'yuel')

    migration.up
    expect { migration.up }.not_to raise_error

    expect(umikin.reload.picture).to eq('custom_umikin')
    expect(jedmund.reload.picture).to eq('custom_jedmund')
    expect(namesake.reload.picture).to eq('yuel')
  end
end
