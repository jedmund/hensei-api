# frozen_string_literal: true

require "rails_helper"

RSpec.describe SummonAuras::Build::Fingerprint do
  let(:series) { create(:summon_series, slug: "spec-series") }
  let(:summon) do
    Summon.without_aura_build do
      create(:summon, granblue_id: "2040900001", element: 2, wiki_raw: "{{Summon\n|aura1=50% boost to Water Elemental ATK.\n}}",
                      summon_series: series)
    end
  end

  def digest = described_class.new.for(summon.reload)

  it "gives the same digest from a record and from a relation" do
    expect(described_class.new.for_relation(Summon.where(id: summon.id))).to eq(summon.id => digest)
  end

  it "changes with the stored page" do
    before = digest
    put_source(summon, :wiki_raw, "{{Summon\n|aura1=60% boost to Water Elemental ATK.\n}}")
    expect(digest).not_to eq(before)
  end

  it "changes with the element and the series slug" do
    before = digest
    summon.update_columns(element: 1)
    after_element = digest
    series.update_columns(slug: "renamed")

    expect(after_element).not_to eq(before)
    expect(digest).not_to eq(after_element)
  end

  it "changes with Build::VERSION" do
    before = digest
    stub_const("SummonAuras::Build::VERSION", SummonAuras::Build::VERSION + 1)
    expect(digest).not_to eq(before)
  end
end
