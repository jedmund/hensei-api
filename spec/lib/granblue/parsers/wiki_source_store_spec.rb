# frozen_string_literal: true

require "rails_helper"
require "webmock"

RSpec.describe Granblue::Parsers::Wiki do
  include WebMock::API

  let(:store) { WeaponSkills::SourceStore::Memory.new }

  around do |example|
    WebMock.enable!
    WebMock.disable_net_connect!(allow_localhost: true)
    stub_request(:any, /gbf\.wiki/).to_return(status: 500)
    example.run
  ensure
    WebMock.reset!
    WebMock.allow_net_connect!
    WebMock.disable!
  end

  def wiki_requests = WebMock::RequestRegistry.instance.requested_signatures.hash.keys

  describe "store mode" do
    it "reads pages, expansions and raw templates from the store inside Wiki.offline" do
      store.put("transclusion", "Lagrange", "base page")
      store.put("wiki_raw", "Ultima Weapons", "series page")
      store.put("wiki_raw", "Gateway-Star Sword", "{{Weapon/Common/Celestial}}")
      store.put("expanded", "Gateway-Star Sword", "<table/>")
      store.put("family_template", "Template:Weapon Skills/Might", "{{WsBox}}")

      described_class.offline(store: store) do
        wiki = described_class.new
        expect(wiki.fetch("Lagrange")).to eq("base page")
        expect(wiki.fetch("Ultima Weapons")).to eq("series page")
        expect(wiki.fetch("Ultima Weapons", kind: "wiki_raw")).to eq("series page")
        expect(wiki.expand("{{Weapon/Common/Celestial}}", page: "Gateway-Star Sword")).to eq("<table/>")
        expect(wiki.fetch_raw("Template:Weapon Skills/Might")).to eq("{{WsBox}}")
      end
      expect(wiki_requests).to be_empty
    end

    it "raises SourceMissing on a miss instead of calling the wiki" do
      described_class.offline(store: store) do
        wiki = described_class.new
        expect { wiki.fetch("Nowhere") }.to raise_error(WeaponSkills::SourceStore::SourceMissing)
        expect { wiki.expand("text", page: "Nowhere") }.to raise_error(WeaponSkills::SourceStore::SourceMissing)
        expect { wiki.expand("text") }.to raise_error(WeaponSkills::SourceStore::SourceMissing)
      end
      expect(wiki_requests).to be_empty
    end

    it "refuses an expansion made from different wikitext" do
      store.put("wiki_raw", "Page", "fetched text")
      store.put("expanded", "Page", "<table/>")

      described_class.offline(store: store) do
        expect { described_class.new.expand("edited text", page: "Page") }
          .to raise_error(WeaponSkills::SourceStore::SourceMissing, /changed since the fetch/)
      end
    end

    it "reads the database store whenever the weapon-skill build is on" do
      allow(WeaponSkills).to receive(:build_mode).and_return("shadow")
      expect(described_class.new.store).to be_a(WeaponSkills::SourceStore::Database)
    end

    it "keeps calling the network outside a scope while the build is off" do
      expect(described_class.new.store).to be_nil
      expect(described_class.new.expand("text")).to be_nil # the stubbed wiki answers 500
      expect(wiki_requests.size).to eq(1) # so the zero-request checks above do detect calls
      expect(described_class.new(store: store).store).to be(store)
      described_class.offline(store: store) { expect(described_class.new(store: nil).store).to be_nil }
    end
  end

  describe "EntityReparser offline" do
    let(:fixture) { Rails.root.join("spec/fixtures/wiki/hrunting.txt").read }
    let(:database) { WeaponSkills::SourceStore::Database.new }
    let(:expanded) do
      <<~HTML
        <table class="weapon-skills">
        <tr><td class="skill-name">Fire's Might</td><td class="skill-desc">Big boost to Fire allies' ATK</td></tr>
        </table>
      HTML
    end

    def store_page(weapon, text, kind: "wiki_raw")
      database.put(kind, weapon.wiki_en, text, weapon_id: weapon.id)
    end

    it "makes no HTTP calls for inline, transcluded and series-template weapons" do
      inline = create(:weapon, granblue_id: "1040022900", wiki_en: "Hrunting", wiki_raw: fixture)
      store_page(inline, fixture)
      database.put("transclusion", "Template:Weapon/Common/Illustrious", "<noinclude/>", weapon_id: inline.id)

      mk2 = create(:weapon, wiki_en: "Hrunting Mk II", wiki_raw: "{{:Hrunting}}")
      store_page(mk2, mk2.wiki_raw)
      database.put("transclusion", "Hrunting", fixture, weapon_id: mk2.id)

      raw = "{{Weapon/Common/Xeno\n|name=Xeno Sword\n|jps1_desc=…\n}}"
      template = create(:weapon, wiki_en: "Xeno Sword", wiki_raw: raw)
      store_page(template, raw)
      store_page(template, expanded, kind: "expanded")

      results = described_class.offline do
        [inline, mk2, template].map { |w| Granblue::EntityReparser.new(w).reparse }
      end

      expect(wiki_requests).to be_empty
      expect(results.map { |r| r[:skills] }).to all(be_positive)
      expect(template.skills.reload.map(&:name_en)).to include("Fire's Might")
    end

    it "fails a reparse whose source is missing without calling the wiki" do
      weapon = create(:weapon, wiki_en: "Unfetched", wiki_raw: "{{Weapon/Common/Xeno\n|name=Unfetched\n}}")

      expect { described_class.offline { Granblue::EntityReparser.new(weapon).reparse } }
        .to raise_error(WeaponSkills::SourceStore::SourceMissing)
      expect(wiki_requests).to be_empty
    end
  end

  describe "#fetch" do
    it "sends the canonical title as an encoded parameter" do
      stub_request(:get, %r{gbf\.wiki/api\.php})
        .with(query: hash_including(action: "parse", page: "Devil's Finger"))
        .to_return(status: 200, body: JSON.generate(parse: { wikitext: { "*" => "page" } }),
                   headers: { "Content-Type" => "application/json" })

      expect(described_class.new(store: nil).fetch("Devil%27s_Finger")).to eq("page")
    end
  end

  describe "#last_edited" do
    it "returns each title's latest edit, following the wiki's title normalization" do
      body = { query: { normalized: [{ from: "ray of Zhuque Regus", to: "Ray of Zhuque Regus" }],
                        pages: [{ title: "Ray of Zhuque Regus", revisions: [{ timestamp: "2026-10-15T12:00:00Z" }] },
                                { title: "Gone", missing: true }] } }
      stub_request(:get, %r{gbf\.wiki/api\.php})
        .with(query: hash_including(action: "query", prop: "revisions", titles: "ray of Zhuque Regus|Gone"))
        .to_return(status: 200, body: JSON.generate(body), headers: { "Content-Type" => "application/json" })

      edited = described_class.new(store: nil).last_edited(%w[ray_of_Zhuque_Regus Gone])

      expect(edited).to eq("ray_of_Zhuque_Regus" => Time.utc(2026, 10, 15, 12), "Gone" => nil)
    end

    it "asks about percent-encoded and padded keys by their plain title" do
      body = { query: { pages: [{ title: "Devil's Finger", revisions: [{ timestamp: "2026-10-01T00:00:00Z" }] }] } }
      stub_request(:get, %r{gbf\.wiki/api\.php})
        .with(query: hash_including(titles: "Devil's Finger"))
        .to_return(status: 200, body: JSON.generate(body), headers: { "Content-Type" => "application/json" })

      edited = described_class.new(store: nil).last_edited(["Devil%27s Finger", "\nDevil's Finger"])

      expect(edited.values).to eq([Time.utc(2026, 10, 1)] * 2)
    end

    it "refuses more than 50 titles" do
      expect { described_class.new(store: nil).last_edited(Array.new(51) { |i| "P#{i}" }) }
        .to raise_error(ArgumentError)
    end
  end
end

