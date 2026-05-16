# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SubstituteGridPreloading, type: :concern do
  # Minimal host that just exposes the concern and a current_user accessor.
  let(:host_class) do
    Class.new do
      include SubstituteGridPreloading
      attr_accessor :current_user
    end
  end

  let(:host) { host_class.new }
  let(:user) { create(:user) }
  let(:party) { create(:party, user: user) }
  let(:weapon) { Weapon.find_by!(granblue_id: '1040611300') }
  let(:other_weapon) { Weapon.find_by!(granblue_id: '1040912100') }

  before { host.current_user = user }

  def collect_sql_queries
    queries = []
    subscriber = ActiveSupport::Notifications.subscribe('sql.active_record') do |_n, _s, _f, _id, payload|
      next if payload[:name].in?(%w[SCHEMA TRANSACTION])

      queries << payload[:sql]
    end
    yield
    ActiveSupport::Notifications.unsubscribe(subscriber)
    queries
  end

  it 'hydrates substitute_grid records and stamps ownership in a bounded query count' do
    gw = create(:grid_weapon, party: party, weapon: weapon)
    sw1 = create(:grid_weapon, party: party, weapon: other_weapon, is_substitute: true)
    sw2 = create(:grid_weapon, party: party, weapon: weapon, is_substitute: true, position: 1)
    create(:substitution, grid: gw, substitute_grid: sw1, position: 0)
    create(:substitution, grid: gw, substitute_grid: sw2, position: 1)

    # Source user owns one of the canonical weapons; the other should report unowned.
    create(:collection_weapon, user: user, weapon: other_weapon)

    # Reload from the party so the substitutions association is unloaded and
    # gets preloaded the same way the controller would.
    fresh_gw = party.weapons.includes(substitutions: :substitute_grid).find(gw.id)

    queries = collect_sql_queries do
      host.send(:preload_substitute_grids!, [fresh_gw])
    end

    # Bound the queries: nested-preloads of the substitute grid associations
    # plus one CollectionWeapon ownership lookup. Should NOT scale with the
    # number of substitute rows. Slack is for Rails-internal noise; if this
    # ever drifts above ~10, that's the N+1 the concern exists to prevent.
    expect(queries.count).to be <= 6

    subs = fresh_gw.substitutions.to_a
    owned_flags = subs.map { |s| s.substitute_grid.owned }
    expect(owned_flags).to match_array([true, false])
  end

  it 'no-ops when there are no substitutions' do
    gw = create(:grid_weapon, party: party, weapon: weapon)
    fresh_gw = party.weapons.includes(:substitutions).find(gw.id)

    expect { host.send(:preload_substitute_grids!, [fresh_gw]) }.not_to raise_error
  end
end
