require 'rails_helper'
require Rails.root.join('db/data/20261003000002_clear_gacha_rateups')

RSpec.describe ClearGachaRateups do
  subject(:migration) { described_class.new }

  let(:connection) { ActiveRecord::Base.connection }
  let(:weapon) { create(:weapon) }
  let(:summon) { create(:summon) }

  def rateup_count
    connection.select_value('SELECT COUNT(*) FROM gacha_rateups').to_i
  end

  before do
    connection.execute(<<~SQL)
      INSERT INTO gacha_rateups (user_id, rate, drawable_type, drawable_id)
      VALUES ('1', 0.3, 'Weapon', '#{weapon.id}'), ('2', 0.5, 'Summon', '#{summon.id}')
    SQL
  end

  it 'deletes every saved rate-up, rerunnably' do
    expect { migration.up }.to change { rateup_count }.from(2).to(0)
    expect { migration.up }.not_to raise_error
  end
end
