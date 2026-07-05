# frozen_string_literal: true

namespace :granblue do
  desc <<~DESC
    Download the in-game weapon-skill label badges (the "Weapon Skill Boosts" panel
    tags) from the game CDN, in English and Japanese, into hensei-svelte's bundled
    assets. gbf.wiki's label gadget CSS maps display labels to the game filenames;
    labels the wiki hosts under renamed files use the hand-recovered map below.
    Usage:
      rake granblue:download_skill_labels                        # missing files, en+ja
      rake granblue:download_skill_labels langs=ja force=true
      rake granblue:download_skill_labels all_labels=true        # every label in the gadget
      rake granblue:download_skill_labels css=tmp/labels.css out=/path/to/skill-labels
  DESC
  task download_skill_labels: :environment do
    require 'net/http'

    langs = (ENV['langs'] || 'en,ja').split(',')
    force = ENV['force'] == 'true'
    throttle = (ENV['throttle'] || '0.4').to_f
    all_labels = ENV['all_labels'] == 'true'
    out_root = Pathname.new(ENV['out'] || Rails.root.join('../hensei-svelte/src/assets/skill-labels'))

    wiki_css_url = 'https://gbf.wiki/MediaWiki:Gadget-common-label-images.css?action=raw'
    cdn = 'https://prd-game-a-granbluefantasy.akamaized.net/%<assets>s/img/sp/ui/icon/weapon_skill_label/%<file>s'
    assets_dir = { 'en' => 'assets_en', 'ja' => 'assets' }
    user_agent = Rails.application.credentials.wiki_user_agent

    # The wiki hosts some labels under renamed files (Book_bonus_label_l_N.png /
    # Bonus_N.png), hiding the game filename; these were recovered by probing the CDN.
    manual = {
      'hp' => '03_icon_hp.png',
      'da-rate' => '01_icon_da_rate.png',
      'ta-rate' => '01_icon_ta_rate.png',
      'ca-dmg' => '04_icon_ca_dmg.png',
      'skill-dmg' => '04_icon_skill_dmg.png',
      'stamina' => '01_icon_stamina_01.png',
      'enmity' => '01_icon_enmity_01.png',
      'plain-amp' => '04_icon_plain_amplify.png', # not in the wiki gadget at all
      'sp-ca-cap' => '04_icon_ca_dmg_cap_ded.png',
      'na-supp' => '04_icon_normal_dmg_supp.png',
      # Destroyer weapons' Destruction bonus damage (game files say "genesis")
      'bonus-des-dmg' => '01_icon_genesis_concurrent_attack.png',
      'bonus-des-dmg-ca' => '01_icon_genesis_special_skill_concurrent_attack.png'
    }
    frames = %w[optimus omega]
    %w[fire water earth wind light dark].each do |el|
      frames.each { |frame| manual["#{el}-#{frame}"] = "01_icon_#{el}#{frame}.png" }
    end

    fetch = lambda do |url|
      uri = URI(url)
      res = Net::HTTP.get_response(uri, { 'User-Agent' => user_agent })
      raise "#{res.code} for #{url}" unless res.is_a?(Net::HTTPSuccess)

      res.body
    end

    slugify = ->(label) { label.downcase.gsub(/[().']/, '').gsub(/[^a-z0-9]+/, '-').gsub(/\A-|-\z/, '') }

    css = ENV['css'] ? File.read(ENV['css']) : fetch.call(wiki_css_url)
    mapping = {}
    css.split('}').each do |block|
      file = block[%r{url\('https://gbf\.wiki/images/[0-9a-f]/[0-9a-f]{2}/([^']+)'\)}, 1]
      next unless file

      block.scan(/data-label='([^']+)'/).flatten.each { |label| mapping[slugify.call(label)] ||= file }
    end
    # Wiki-renamed files aren't game filenames — the manual map overrides them.
    mapping = mapping.reject { |_, f| f.match?(/\A(Book_bonus_label|Bonus_)/) }.merge(manual)
    puts "#{mapping.size} labels known"

    slugs = all_labels ? mapping.keys.sort : out_root.join('en').glob('*.png').map { |p| p.basename('.png').to_s }.sort
    unknown = slugs - mapping.keys
    puts "WARNING: no filename for: #{unknown.join(', ')}" if unknown.any?
    slugs &= mapping.keys

    failures = []
    langs.each do |lang|
      dir = out_root.join(lang)
      dir.mkpath
      todo = slugs.select { |s| force || !dir.join("#{s}.png").exist? }
      puts "[#{lang}] #{todo.size} to download (#{slugs.size - todo.size} already present)"
      todo.each do |slug|
        url = format(cdn, assets: assets_dir.fetch(lang), file: mapping.fetch(slug))
        begin
          data = fetch.call(url)
          dir.join("#{slug}.png").binwrite(data)
          puts "  #{slug} <- #{mapping[slug]} (#{data.bytesize} bytes)"
        rescue StandardError => e
          failures << [lang, slug, e.message]
          warn "  FAILED #{slug}: #{e.message}"
        end
        sleep(throttle) if throttle.positive?
      end
    end

    puts failures.any? ? "#{failures.size} failure(s)" : 'done'
    exit(1) if failures.any?
  end
end
