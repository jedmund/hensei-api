# frozen_string_literal: true

require "rails_helper"

RSpec.describe WeaponSkills::SourceStore::Fetcher do
  # Stands in for Granblue::Parsers::Wiki: pages by title, expansions by text.
  let(:fake_wiki_class) do
    Class.new do
      attr_reader :calls

      def initialize(pages: {}, expansions: {}, raw: {}, errors: {})
        @pages = pages
        @expansions = expansions
        @raw = raw
        @errors = errors
        @calls = []
      end

      def fetch(page)
        @calls << [:fetch, page]
        raise @errors[page].shift if @errors[page].present?
        raise Granblue::WikiError.new(code: "missingtitle", message: "missing", page: page) unless @pages.key?(page)

        @pages[page]
      end

      def expand(text) = (@calls << [:expand, text]) && @expansions[text]

      def fetch_raw(title) = (@calls << [:fetch_raw, title]) && @raw[title]
    end
  end

  let(:store) { WeaponSkills::SourceStore::Database.new }
  let(:fixture) { Rails.root.join("spec/fixtures/wiki/hrunting.txt").read }

  def fetcher(wiki, **)
    described_class.new(store: store, wiki: wiki, delay: 0, backoff: 0, **)
  end

  describe ".page_kind" do
    it "tells inline, series-template and key-determined pages apart" do
      expect(described_class.page_kind("{{Weapon/Common/PremiumSSR\n|s1_desc=Big boost\n}}")).to eq("inline")
      expect(described_class.page_kind("{{Weapon/Common/Xeno\n|jps1_desc=…\n}}")).to eq("series_template")
      expect(described_class.page_kind("{{Weapon/Common/Dark Opus\n}}",
                                       "<td class=\"skill-desc\">Empowered by a chosen pendulum.</td>"))
        .to eq("key_determined")
      expect(described_class.page_kind("plain page")).to eq("inline")
    end
  end

  describe "#fetch_weapon" do
    it "stores the page, its expansion and the pages its parse follows" do
      weapon = create(:weapon, wiki_en: "Hrunting", wiki_raw: "stale")
      wiki = fake_wiki_class.new(pages: { "Hrunting" => fixture, "Template:Weapon/Common/Illustrious" => "<noinclude/>" },
                                 expansions: { fixture => "<table class=\"weapon-skills\"></table>" })

      fetcher(wiki).fetch_weapon(weapon)

      sources = WeaponSource.where(weapon_id: weapon.id).index_by(&:kind)
      expect(sources.keys).to contain_exactly("wiki_raw", "expanded", "transclusion")
      expect(sources["wiki_raw"].body).to eq(fixture)
      expect(sources["transclusion"].key).to eq("Template:Weapon/Common/Illustrious")
      expect(weapon.reload.wiki_raw).to eq(fixture)
      expect(weapon.wiki_raw_fetched_at).to be_present
      # the structural parse that found the followed page was rolled back
      expect(weapon.weapon_skills).to be_empty
    end

    it "follows a redirect and points wiki_en at the target" do
      weapon = create(:weapon, wiki_en: "Old Name")
      wiki = fake_wiki_class.new(pages: { "Old Name" => "#REDIRECT [[New Name]]", "New Name" => "plain page" })

      fetcher(wiki).fetch_weapon(weapon)

      expect(weapon.reload.wiki_en).to eq("New Name")
      expect(store.fetch("wiki_raw", "New Name").body).to eq("plain page")
    end

    it "retries transient errors" do
      weapon = create(:weapon, wiki_en: "Flaky")
      wiki = fake_wiki_class.new(pages: { "Flaky" => "plain page" },
                                 errors: { "Flaky" => [Granblue::WikiError.new(code: 503, message: "Server error")] })

      fetcher(wiki).fetch_weapon(weapon)

      expect(wiki.calls.count([:fetch, "Flaky"])).to eq(2)
      expect(store.fetch("wiki_raw", "Flaky").body).to eq("plain page")
    end

    it "raises when the page itself is missing" do
      weapon = create(:weapon, wiki_en: "Gone")

      expect { fetcher(fake_wiki_class.new).fetch_weapon(weapon) }.to raise_error(Granblue::WikiError)
      expect(WeaponSource.count).to eq(0)
    end

    it "reports a followed page that can't be fetched" do
      weapon = create(:weapon, wiki_en: "Mk II")
      wiki = fake_wiki_class.new(pages: { "Mk II" => "{{:Missing Base}}" })
      f = fetcher(wiki)

      f.fetch_weapon(weapon)

      expect(f.failures).to include(a_hash_including(kind: "transclusion", key: "Missing Base"))
      expect(store.exist?("transclusion", "Missing Base")).to be(false)
    end
  end

  describe "shared pages" do
    it "stores family templates and key series pages without a weapon" do
      title = "Template:Weapon Skills/Might"
      wiki = fake_wiki_class.new(pages: { "Ultima Weapons" => "series" }, raw: { title => "{{WsBox}}" })
      f = fetcher(wiki)

      f.fetch_family_template("Might")
      f.fetch_family_template("Nothing")
      f.fetch_series_page("Ultima Weapons")

      expect(WeaponSource.where(weapon_id: nil).pluck(:kind, :key))
        .to contain_exactly(["family_template", title], ["wiki_raw", "Ultima Weapons"])
      expect(f.failures).to contain_exactly(a_hash_including(key: "Template:Weapon Skills/Nothing"))
    end
  end
end
