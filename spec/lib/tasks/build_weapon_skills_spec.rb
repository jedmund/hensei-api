# frozen_string_literal: true

require "rails_helper"
require "rake"

RSpec.describe "granblue:build_weapon_skills" do
  let(:runner) { instance_double(WeaponSkills::Build::Runner, call: WeaponSkills::Build::Runner::Summary.new(failed: 0)) }

  before(:all) do
    Rails.application.load_tasks unless Rake::Task.task_defined?("granblue:build_weapon_skills")
  end

  around do |example|
    keys = %w[ids series all mode WEAPON_SKILL_BUILD]
    saved = keys.to_h { |k| [k, ENV.fetch(k, nil)] }
    keys.each { |k| ENV.delete(k) }
    example.run
  ensure
    saved.each { |k, v| v.nil? ? ENV.delete(k) : ENV[k] = v }
  end

  before do
    allow(WeaponSkills::Build::Runner).to receive(:new).and_return(runner)
    allow(ActiveRecord::Base).to receive(:logger=)
  end

  def invoke
    Rake::Task["granblue:build_weapon_skills"].reenable
    Rake::Task["granblue:build_weapon_skills"].invoke
  end

  it "defaults to stale weapons in shadow mode while the build is off" do
    invoke
    expect(WeaponSkills::Build::Runner).to have_received(:new).with(mode: "shadow", ids: nil, series: nil, all: false)
  end

  it "defaults to write mode when WEAPON_SKILL_BUILD=write" do
    ENV["WEAPON_SKILL_BUILD"] = "write"
    invoke
    expect(WeaponSkills::Build::Runner).to have_received(:new).with(hash_including(mode: "write"))
  end

  it "passes ids=, series=, all= and mode=" do
    ENV.update("ids" => "1040000001, 1040000002", "series" => "celestial", "all" => "true", "mode" => "write")
    invoke
    expect(WeaponSkills::Build::Runner).to have_received(:new)
      .with(mode: "write", ids: %w[1040000001 1040000002], series: %w[celestial], all: true)
  end

  it "exits nonzero when a weapon failed" do
    allow(runner).to receive(:call).and_return(WeaponSkills::Build::Runner::Summary.new(failed: 1))
    expect { invoke }.to raise_error(SystemExit) { |e| expect(e.status).to eq(1) }
  end
end
