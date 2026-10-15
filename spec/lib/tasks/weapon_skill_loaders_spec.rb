# frozen_string_literal: true

require 'rails_helper'
require 'rake'

# The JSON snapshot loaders own canonical rows only. A version-linked row with the
# same key must never be matched, overwritten or claimed by them.
RSpec.describe 'weapon-skill JSON loaders' do
  before(:all) do
    Rails.application.load_tasks if Rake::Task.tasks.none? { |t| t.name == 'granblue:load_weapon_skill_data' }
  end

  around do |example|
    seed = ENV.fetch('SEED', nil)
    ENV['SEED'] = '1'
    example.run
  ensure
    ENV['SEED'] = seed
  end

  def run_task(name)
    Rake::Task[name].reenable
    expect { Rake::Task[name].invoke }.to output.to_stdout
  end

  let(:version) { create(:weapon_skill_version) }

  it 'load_weapon_skill_data leaves a version-linked row with a canonical key alone' do
    record = JSON.parse(Rails.root.join('data/weapon_skill_data.json').read).first
    linked = WeaponSkillDatum.create!(
      weapon_skill_version_id: version.id, modifier: record['modifier'], boost_type: record['boost_type'],
      series: record['series'], size: record['size'], formula_type: 'flat', sl15: 99.0
    )

    run_task('granblue:load_weapon_skill_data')

    expect(linked.reload).to have_attributes(weapon_skill_version_id: version.id, sl15: 99.0)
    canonical = WeaponSkillDatum.find_by(weapon_skill_version_id: nil, modifier: record['modifier'],
                                         boost_type: record['boost_type'], series: record['series'],
                                         size: record['size'])
    expect(canonical).to be_present
  end

  it 'load_weapon_skill_effects leaves a version-linked effect with a canonical key alone' do
    payload = JSON.parse(Rails.root.join('data/weapon_skill_effects.json').read)
    record = payload['effects'].find { |r| r['key_slug'].nil? }
    linked = WeaponSkillEffect.create!(
      weapon_skill_version_id: version.id, modifier: record['modifier'], boost_type: record['boost_type'],
      scaling_kind: record['scaling_kind'], condition: record['condition'] || {}, value: 99.0,
      stacking: 'additive'
    )

    run_task('granblue:load_weapon_skill_effects')

    expect(linked.reload).to have_attributes(weapon_skill_version_id: version.id, value: 99.0)
    expect(WeaponSkillEffect.where(weapon_skill_version_id: nil, modifier: record['modifier'],
                                   boost_type: record['boost_type'], scaling_kind: record['scaling_kind']))
      .to exist
  end
end
