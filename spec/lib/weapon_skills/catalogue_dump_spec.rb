# frozen_string_literal: true

require "rails_helper"
require "rake"

RSpec.describe WeaponSkills::CatalogueDump do
  let(:connection) { ActiveRecord::Base.connection }

  it "names only tables that exist" do
    expect(described_class::TABLES - connection.tables).to eq([])
  end

  it "never includes user data" do
    offenders = described_class::TABLES.flat_map do |table|
      connection.columns(table).map(&:name).grep(described_class::USER_DATA_COLUMN).map { |c| "#{table}.#{c}" }
    end
    expect(offenders).to eq([])
    expect(described_class::TABLES & %w[users parties grid_weapons collection_weapons crews oauth_access_tokens]).to eq([])
  end

  it "dumps data only, with every table named" do
    command = described_class.pg_dump_command("postgres:///x", "out.dump")
    expect(command).to include("--data-only")
    expect(command.each_cons(2).filter_map { |flag, table| table if flag == "-t" }).to eq(described_class::TABLES)
  end

  describe ".release_exists?" do
    let(:status) { instance_double(Process::Status, success?: true, exitstatus: 0) }

    it "lists releases, drafts included, instead of looking up a git tag" do
      allow(Open3).to receive(:capture2).and_return(["catalogue-20261015\ncatalogue-20261015-prod\n", status])

      expect(described_class.release_exists?("catalogue-20261015")).to be(true)
      expect(described_class.release_exists?("catalogue-20261016")).to be(false)
      expect(Open3).to have_received(:capture2)
        .with("gh", "release", "list", "--repo", described_class::REPO, any_args).twice
    end

    it "raises when gh fails, rather than publishing blind" do
      failed = instance_double(Process::Status, success?: false, exitstatus: 1)
      allow(Open3).to receive(:capture2).and_return(["", failed])

      expect { described_class.release_exists?("catalogue-20261015") }.to raise_error(/gh release list failed/)
    end
  end

  describe "granblue:export_catalogue_dump" do
    before(:all) { Rails.application.load_tasks unless Rake::Task.task_defined?("granblue:export_catalogue_dump") }

    around do |example|
      saved = ENV.to_h.slice("publish", "tag")
      ENV["publish"] = "true"
      ENV["tag"] = "catalogue-20261015"
      example.run
    ensure
      ENV.delete("publish")
      ENV.delete("tag")
      ENV.update(saved)
    end

    it "refuses to publish over an existing release, before dumping anything" do
      allow(described_class).to receive(:release_exists?).with("catalogue-20261015").and_return(true)
      allow(described_class).to receive(:pg_dump_command)
      task = Rake::Task["granblue:export_catalogue_dump"]
      task.reenable

      expect { task.invoke }.to raise_error(SystemExit).and output(/already exists.*tag=/m).to_stderr
      expect(described_class).not_to have_received(:pg_dump_command)
    end
  end
end
