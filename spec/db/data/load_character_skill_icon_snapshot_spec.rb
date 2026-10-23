# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'LoadCharacterSkillIconSnapshot' do
  let(:migration_class) do
    unless defined?(LoadCharacterSkillIconSnapshot)
      require Rails.root.join('db/data/20261022110200_load_character_skill_icon_snapshot')
    end
    LoadCharacterSkillIconSnapshot
  end

  def run
    migration_class.new.tap { |m| m.verbose = false }.up
  end

  # The committed file is gone (PR 7b drop); a stand-in as it was exported.
  let(:path) { Rails.root.join('tmp', "icons-#{SecureRandom.hex(4)}.json") }

  after { FileUtils.rm_f(path) }

  it 'stores the file byte for byte, so fingerprints keep its digest' do
    File.write(path, "[\n  {\"granblue_id\":\"3040377000\",\"name_en\":\"Jinx\",\"game_icon\":\"2559_3\"}\n]\n")
    stub_const("#{migration_class}::PATH", path)
    run

    row = Source.fetch(nil, :icon_snapshot, key: CharacterSkills::IconSnapshot::KEY)
    expect(row.body.b).to eq(File.binread(migration_class::PATH))
    expect(row.sha256).to eq(Digest::SHA256.file(migration_class::PATH).hexdigest)
    expect(CharacterSkills::Build::Fingerprint.new.icons_digest).to eq(row.sha256)
  end

  it 'keeps a stored snapshot' do
    put_icon_snapshot("[]\n")
    run
    expect(Source.read(nil, :icon_snapshot, key: CharacterSkills::IconSnapshot::KEY)).to eq("[]\n")
  end

  it 'stores nothing without the file' do
    expect(File.exist?(migration_class::PATH)).to be(false)
    run
    expect(CharacterSkills::IconSnapshot.sha256).to be_nil
  end
end
