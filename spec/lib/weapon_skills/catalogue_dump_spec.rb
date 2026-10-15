# frozen_string_literal: true

require "rails_helper"

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
end
