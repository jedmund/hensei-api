# frozen_string_literal: true

require "rails_helper"

RSpec.describe WeaponSkills::SourceStore::Freshness do
  let(:fetched_at) { Time.utc(2026, 10, 15, 13, 0) }
  let(:edited) { {} }
  let(:fetcher) do
    edits = edited
    Class.new do
      attr_reader :batches

      define_method(:initialize) { @batches = [] }
      define_method(:last_edited) do |titles|
        @batches << titles
        titles.index_with { |t| edits.fetch(t, Time.utc(2026, 1, 1)) }
      end
    end.new
  end
  let(:freshness) { described_class.new(fetcher: fetcher) }

  def source(kind, key, weapon: nil)
    WeaponSource.create!(weapon: weapon, kind: kind, key: key, body: "x", fetched_at: fetched_at)
  end

  it "flags a weapon whose page or followed template was edited since the fetch" do
    edited_page = create(:weapon)
    via_template = create(:weapon)
    untouched = create(:weapon)
    source("wiki_raw", "Edited", weapon: edited_page)
    source("wiki_raw", "Via", weapon: via_template)
    source("transclusion", "Template:Weapon/Common/Destroyer", weapon: via_template)
    source("wiki_raw", "Untouched", weapon: untouched)
    source("expanded", "Untouched", weapon: untouched)
    edited["Edited"] = fetched_at + 1.hour
    edited["Template:Weapon/Common/Destroyer"] = fetched_at + 2.days

    result = freshness.check

    expect(result.weapon_ids).to contain_exactly(edited_page.id, via_template.id)
    expect(result.shared).to be_empty
    expect(result.checked).to eq(4) # expansions aren't wiki pages; they're refetched with their weapon
  end

  it "flags shared pages and lists titles the wiki no longer has" do
    source("family_template", "Template:Weapon Skills/Might")
    source("wiki_raw", "Gone Page", weapon: create(:weapon))
    edited["Template:Weapon Skills/Might"] = fetched_at + 1.minute
    edited["Gone Page"] = nil

    result = freshness.check

    expect(result.shared).to eq([["family_template", "Template:Weapon Skills/Might"]])
    expect(result.missing).to eq(["Gone Page"])
  end

  it "asks about at most 50 titles per request" do
    120.times { |i| source("family_template", "Template:Weapon Skills/F#{i}") }

    freshness.check

    expect(fetcher.batches.map(&:size)).to eq([50, 50, 20])
  end
end
