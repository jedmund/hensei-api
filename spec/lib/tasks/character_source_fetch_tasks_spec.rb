# frozen_string_literal: true

require 'rails_helper'
require 'rake'

# The PR 4 backfill tasks: the source fetches (wiki, JP wiki, game data) and the coverage
# report. Every request is stubbed (WebMock blocks the rest) and the throttle never sleeps.
RSpec.describe 'character source fetch tasks' do
  let(:tmp_dir) { Rails.root.join('tmp', "source_fetch_spec_#{Process.pid}") }

  before(:all) do
    Rails.application.load_tasks unless Rake::Task.task_defined?('granblue:character_skill_coverage')
  end

  around do |example|
    keys = %w[type id ids rarity force delay changed_out build missing model limit throttle format out s3 s3_delay
              debug lang style ACCESS_TOKEN WING MIDSHIP]
    saved = keys.to_h { |k| [k, ENV.fetch(k, nil)] }
    keys.each { |k| ENV.delete(k) }
    example.run
  ensure
    saved.each { |k, v| v.nil? ? ENV.delete(k) : ENV[k] = v }
    FileUtils.rm_rf(tmp_dir)
  end

  before do
    allow(Granblue::WikiThrottle).to receive(:wait)
    allow(ActiveRecord::Base).to receive(:logger).and_return(Logger.new(IO::NULL))
    allow(ActiveRecord::Base).to receive(:logger=)
  end

  def invoke(name, **env)
    env.each { |k, v| ENV[k.to_s] = v.to_s }
    Rake::Task[name].reenable
    output = StringIO.new
    original = $stdout
    $stdout = output
    begin
      Rake::Task[name].invoke
    ensure
      $stdout = original
    end
    output.string
  end

  def stub_wiki_page(title, text)
    stub_request(:get, %r{\Ahttps://gbf\.wiki/api\.php})
      .with(query: hash_including(action: 'parse', page: title))
      .to_return(status: 200, body: JSON.generate(parse: { wikitext: { '*' => text } }),
                 headers: { 'Content-Type' => 'application/json' })
  end

  describe 'granblue:fetch_wiki_data' do
    let!(:ssr) do
      create(:character, granblue_id: '3040000101', name_en: 'Same', wiki_en: 'Same', rarity: 3, wiki_raw: '{{Same}}')
    end
    let!(:ssr_style) do
      create(:character, granblue_id: '3040000101', name_en: 'Same', wiki_en: 'Same (Style)', rarity: 3,
                         style_swap: true, wiki_raw: '{{Old style}}')
    end
    let!(:other_ssr) do
      create(:character, granblue_id: '3040000102', name_en: 'Rebalanced', wiki_en: 'Rebalanced', rarity: 3,
                         wiki_raw: '{{Old}}')
    end
    let!(:blank_sr) { create(:character, granblue_id: '3030000103', name_en: 'Lost', wiki_en: 'Lost', rarity: 2, wiki_raw: nil) }
    let!(:filled_r) { create(:character, granblue_id: '3020000104', name_en: 'Fine', wiki_en: 'Fine', rarity: 1, wiki_raw: '{{R}}') }
    let!(:untitled_sr) { create(:character, granblue_id: '3030000105', name_en: 'Untitled', wiki_en: '', rarity: 2, wiki_raw: nil) }

    # The test database carries seeded characters; rarity= runs are narrowed to this spec's rows.
    let(:own_ids) { '3040000101,3040000102,3030000103,3020000104,3030000105' }

    before do
      stub_wiki_page('Same', '{{Same}}')
      stub_wiki_page('Same (Style)', '{{New style}}')
      stub_wiki_page('Rebalanced', '{{New}}')
      stub_wiki_page('Lost', '{{Found}}')
      stub_wiki_page('Fine', '{{R}}')
    end

    it 'refetches ids= with force, both style rows, and reports unchanged and changed' do
      out = nil
      expect { out = invoke('granblue:fetch_wiki_data', ids: '3040000101,3040000102', force: true) }
        .not_to have_enqueued_job(CharacterSkills::BuildJob)

      expect(ssr.reload.wiki_raw).to eq('{{Same}}')
      expect(ssr_style.reload.wiki_raw).to eq('{{New style}}')
      expect(other_ssr.reload.wiki_raw).to eq('{{New}}')
      expect(out).to include('fetch_wiki_data: fetched 3 (unchanged 1, changed 2), skipped 0, errors 0')
      expect(out).to include('Changed (2): 3040000101,3040000102')
      expect(Granblue::WikiThrottle).to have_received(:wait).with(2.0).exactly(3).times
    end

    it 'without force skips rows that have wiki_raw' do
      out = invoke('granblue:fetch_wiki_data', ids: '3040000101')
      expect(out).to include('fetched 0 (unchanged 0, changed 0), skipped 2 (has wiki_raw: 2)')
      expect(WebMock).not_to have_requested(:get, /gbf\.wiki/)
      expect(Granblue::WikiThrottle).not_to have_received(:wait)
    end

    it 'keeps id= for one granblue_id' do
      out = invoke('granblue:fetch_wiki_data', id: '3040000102', force: true)
      expect(out).to include('fetched 1 (unchanged 0, changed 1)')
    end

    it 'narrows by rarity= and fills only what is missing (the R/SR run)' do
      out = invoke('granblue:fetch_wiki_data', rarity: '1,2', ids: own_ids)

      expect(blank_sr.reload.wiki_raw).to eq('{{Found}}')
      expect(filled_r.reload.wiki_raw_fetched_at).to be_nil
      expect(other_ssr.reload.wiki_raw).to eq('{{Old}}')
      expect(out).to include('fetched 1 (unchanged 0, changed 1), skipped 2 (has wiki_raw: 1, no wiki_en: 1)')
    end

    it 'refetches every row of a rarity with force (the SSR run)' do
      out = invoke('granblue:fetch_wiki_data', ids: own_ids, rarity: '3', force: true)
      expect(out).to include('fetched 3 (unchanged 1, changed 2), skipped 0, errors 0')
      expect(blank_sr.reload.wiki_raw).to be_nil
    end

    it 'counts errors and carries on' do
      stub_request(:get, %r{gbf\.wiki/api\.php}).with(query: hash_including(page: 'Rebalanced')).to_return(status: 500)
      out = invoke('granblue:fetch_wiki_data', ids: '3040000102,3030000103', force: true)
      expect(out).to include('fetched 1 (unchanged 0, changed 1), skipped 0, errors 1')
      expect(out).to include('error 3040000102 (3040000102 Rebalanced)')
      expect(Granblue::WikiThrottle).to have_received(:wait).twice
    end

    it 'reports ids that are not in the database' do
      out = invoke('granblue:fetch_wiki_data', ids: '3040000102,3999999999', force: true)
      expect(out).to include('Not in the database: 3999999999')
      expect(out).to include('skipped 1 (not in database: 1)')
    end

    it 'never waits less than 2 seconds' do
      invoke('granblue:fetch_wiki_data', ids: '3030000103', delay: '0.5')
      expect(Granblue::WikiThrottle).to have_received(:wait).with(2.0).once
    end

    it 'writes the changed list to changed_out= and prints the build command' do
      path = tmp_dir.join('changed.txt')
      out = invoke('granblue:fetch_wiki_data', ids: own_ids, rarity: '3', force: true, changed_out: path)

      expect(File.read(path)).to eq("3040000101\n3040000102\n")
      expect(out).to include('bin/rails granblue:build_character_skills mode=shadow ids=3040000101,3040000102')
      expect(out).to include('granblue:build_character_skills mode=write')
    end

    it 'runs the build over the changed characters with build=' do
      runner = instance_double(CharacterSkills::Build::Runner, call: nil)
      allow(CharacterSkills::Build::Runner).to receive(:new).and_return(runner)

      invoke('granblue:fetch_wiki_data', ids: own_ids, rarity: '3', force: true, build: 'shadow')

      expect(CharacterSkills::Build::Runner).to have_received(:new).with(mode: 'shadow', ids: %w[3040000101 3040000102])
      expect(runner).to have_received(:call)
    end

    it 'builds nothing when nothing changed' do
      allow(CharacterSkills::Build::Runner).to receive(:new)
      out = invoke('granblue:fetch_wiki_data', ids: '3020000104', force: true, build: 'write')
      expect(out).to include('No character source changed; nothing to build.')
      expect(CharacterSkills::Build::Runner).not_to have_received(:new)
    end

    it 'rejects a bad rarity' do
      expect { invoke('granblue:fetch_wiki_data', rarity: '4') }.to raise_error(SystemExit)
        .and output(/rarity must be 1, 2 or 3/).to_stderr
    end

    it 'rejects a bad build mode' do
      expect { invoke('granblue:fetch_wiki_data', build: 'yes') }.to raise_error(SystemExit)
        .and output(/build must be shadow or write/).to_stderr
    end

    it 'builds only characters' do
      expect { invoke('granblue:fetch_wiki_data', type: 'Weapon', build: 'write') }.to raise_error(SystemExit)
        .and output(/only applies to type=Character/).to_stderr
    end
  end

  describe 'granblue:download_jp_wiki' do
    let!(:cached) do
      create(:character, granblue_id: '3040000201', name_jp: 'キャッシュ', wiki_ja: '', rarity: 3, wiki_raw_jp: '<html>same</html>')
    end
    let!(:missing) do
      create(:character, granblue_id: '3040000202', name_jp: 'ミッシング', wiki_ja: '', rarity: 3, wiki_raw_jp: nil)
    end
    let!(:stale) do
      create(:character, granblue_id: '3040000203', name_jp: 'ステイル', wiki_ja: '', rarity: 3, wiki_raw_jp: '<html>old</html>')
    end

    before do
      allow(Granblue::Parsers::JpWiki).to receive(:new).and_wrap_original do |original, **kwargs|
        original.call(**kwargs).tap do |client|
          allow(client).to receive(:fetch) { |title| title.start_with?('キャッシュ') ? '<html>same</html>' : '<html>new</html>' }
        end
      end
    end

    it 'fetches only blank rows with missing=true' do
      out = nil
      expect { out = invoke('granblue:download_jp_wiki', missing: true, ids: '3040000201,3040000202,3040000203') }
        .not_to have_enqueued_job(CharacterSkills::BuildJob)

      expect(missing.reload.wiki_raw_jp).to eq('<html>new</html>')
      expect(stale.reload.wiki_raw_jp).to eq('<html>old</html>')
      expect(out).to include('download_jp_wiki: fetched 1 (unchanged 0, changed 1), skipped 0, errors 0')
      expect(Granblue::WikiThrottle).to have_received(:wait).with(2.0).once
    end

    it 'refetches ids= with force and tells unchanged from changed' do
      out = invoke('granblue:download_jp_wiki', ids: '3040000201,3040000203', force: true)

      expect(stale.reload.wiki_raw_jp).to eq('<html>new</html>')
      expect(out).to include('fetched 2 (unchanged 1, changed 1)')
      expect(out).to include('Changed (1): 3040000203')
    end

    it 'skips cached ids= rows without force' do
      out = invoke('granblue:download_jp_wiki', ids: '3040000201,3040000202')
      expect(out).to include('fetched 1 (unchanged 0, changed 1), skipped 1 (has wiki_raw_jp: 1)')
      expect(Granblue::WikiThrottle).to have_received(:wait).once
    end

    it 'writes changed_out=' do
      path = tmp_dir.join('jp.txt')
      invoke('granblue:download_jp_wiki', ids: '3040000202', changed_out: path)
      expect(File.read(path)).to eq("3040000202\n")
    end
  end

  describe 'granblue:fetch_game_data' do
    let(:payload) do
      JSON.parse(Rails.root.join('spec/fixtures/character_skills/character-cidala-gamedata.json').read)
          .merge('style_list' => [])
    end
    let!(:cidala) { create(:character, granblue_id: '3040377000', game_raw_en: nil) }
    let!(:unchanged) { create(:character, granblue_id: '3040000301', game_raw_en: nil) }

    before do
      put_source(unchanged, :game_raw_en, payload.merge('id' => '3040000301'))
      %w[3040377000 3040000301].each do |id|
        stub_request(:post, %r{\Ahttps://game\.granbluefantasy\.jp/archive/npc_detail})
          .with(body: hash_including('character_id' => id, 'style' => 1))
          .to_return(status: 200, body: payload.merge('id' => id).to_json, headers: { 'Content-Type' => 'application/json' })
      end
      allow(Dataminer).to receive(:new).and_wrap_original do |original, **kwargs|
        original.call(**kwargs).tap { |miner| allow(miner).to receive(:sleep) }
      end
    end

    it 'stores without queueing builds and prints the summary' do
      out = nil
      expect do
        out = invoke('granblue:fetch_game_data', ACCESS_TOKEN: 't', WING: 'w', MIDSHIP: 'm', ids: '3040377000,3040000301')
      end.not_to have_enqueued_job(CharacterSkills::BuildJob)

      expect(cidala.reload.game_raw_en['id']).to eq('3040377000')
      expect(out).to include('fetch_game_data: fetched 2 (unchanged 1, changed 1), skipped 0, errors 0')
      expect(out).to include('mode=shadow ids=3040377000')
    end

    it 'stops on an expired session and prints how to resume' do
      stub_request(:post, %r{archive/npc_detail}).with(body: hash_including('character_id' => '3040000301'))
                                                 .to_return(status: 200, body: '{"auth_status":"require_auth"}')
      expect do
        invoke('granblue:fetch_game_data', ACCESS_TOKEN: 't', WING: 'w', MIDSHIP: 'm', ids: '3040377000,3040000301,3040000302')
      end.to raise_error(SystemExit).and output(/2 Characters not fetched.*ids=3040000301,3040000302/m).to_stderr
      expect(cidala.reload.game_raw_en['id']).to eq('3040377000')
    end

    it 'never paces the game faster than 2 seconds' do
      invoke('granblue:fetch_game_data', ACCESS_TOKEN: 't', WING: 'w', MIDSHIP: 'm', ids: '3040377000', delay: '0.5')
      expect(Dataminer).to have_received(:new).with(hash_including(delay: 2.0))
    end

    it 'counts a response it cannot store as skipped' do
      stub_request(:post, %r{archive/npc_detail}).with(body: hash_including('character_id' => '3040000399'))
                                                 .to_return(status: 200, body: '{"popup":{}}')
      out = invoke('granblue:fetch_game_data', ACCESS_TOKEN: 't', WING: 'w', MIDSHIP: 'm', ids: '3040000399')
      expect(out).to include('skipped 1 (no character payload: 1)')
    end
  end

  describe 'granblue:character_skill_coverage' do
    let!(:character) { create(:character, granblue_id: '3040000401', rarity: 3, wiki_raw: nil) }

    before do
      skill = create(:character_skill, character: character, kind: :ability, position: 1)
      create(:character_skill_version, character_skill: skill, ordinal: 1, name_en: 'A', game_icon: '9_1')
    end

    it 'prints the report for ids=' do
      out = invoke('granblue:character_skill_coverage', ids: '3040000401')
      expect(out).to match(/Blank wiki_raw\s+1\s+0\s+0\s+1\s+1/)
    end

    it 'writes the gaps with format=csv to out=' do
      path = tmp_dir.join('coverage.csv')
      invoke('granblue:character_skill_coverage', ids: '3040000401', format: 'csv', out: path)
      expect(CSV.read(path, headers: true).map { |r| r['check'] }).to include('wiki_raw_blank', 'no_game_raw_en')
    end

    it 'HEAD-checks icons through AwsService with s3=true' do
      storage = instance_double(AwsService)
      allow(storage).to receive(:file_exists?).and_return(false)
      allow(AwsService).to receive(:new).and_return(storage)

      out = invoke('granblue:character_skill_coverage', ids: '3040000401', s3: true, s3_delay: 0)

      expect(storage).to have_received(:file_exists?).with('icons/abilities/9_1.png')
      expect(out).to match(%r{Stored stems missing from icons/abilities/.*\s+1\s+0\s+0\s+1\s+1})
    end

    it 'rejects an unknown format' do
      expect { invoke('granblue:character_skill_coverage', format: 'xml') }.to raise_error(SystemExit)
        .and output(/format must be text or csv/).to_stderr
    end
  end
end
