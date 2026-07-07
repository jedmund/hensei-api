# frozen_string_literal: true

namespace :granblue do
  desc <<~DESC
    Download the in-game weapon-skill label badges (the "Weapon Skill Boosts" panel
    tags) from the game CDN, in English and Japanese, to S3/local storage alongside
    the rest of our images (icons/skill-labels/{en,ja}/<slug>.png). gbf.wiki's label
    gadget CSS maps display labels to the game filenames; labels the wiki hosts under
    renamed files use the hand-recovered map below.
    Usage:
      rake granblue:download_skill_labels                        # storage=both
      rake granblue:download_skill_labels storage=s3 force=true
      rake granblue:download_skill_labels all_labels=true        # every label in the gadget
      rake granblue:download_skill_labels css=tmp/labels.css only=might,ex-might
  DESC
  task download_skill_labels: :environment do
    require 'net/http'

    storage = (ENV['storage'] || 'both').to_sym
    force = ENV['force'] == 'true'
    throttle = (ENV['throttle'] || '0.4').to_f
    all_labels = ENV['all_labels'] == 'true'

    wiki_css_url = 'https://gbf.wiki/MediaWiki:Gadget-common-label-images.css?action=raw'
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
      'dmg-cap-sp' => '04_icon_dmg_cap_other.png',
      'ca-amp-sp' => '04_icon_ca_dmg_amplify_other.png',
      'cb-dmg' => '04_icon_cb_dmg.png',
      'cb-amp' => '04_icon_cb_dmg_amplify.png',
      'fc-amp' => '04_icon_fc_dmg_amplify.png',
      'debuff-res' => '02_icon_debuff_res.png',
      'added-hp' => '06_icon_hp.png', # overskill (teal) HP
      # Destroyer weapons' Destruction bonus damage (game files say "genesis")
      'bonus-des-dmg' => '01_icon_genesis_concurrent_attack.png',
      'bonus-des-dmg-ca' => '01_icon_genesis_special_skill_concurrent_attack.png'
    }
    frames = %w[optimus omega]
    %w[fire water earth wind light dark].each do |el|
      frames.each { |frame| manual["#{el}-#{frame}"] = "01_icon_#{el}#{frame}.png" }
      # elemental Bonus C.A. DMG badges ("Bonus Earth C.A.")
      manual["bonus-#{el}-ca"] = "01_icon_#{el}_special_skill_concurrent_attack.png"
    end

    fetch = lambda do |url|
      res = Net::HTTP.get_response(URI(url), { 'User-Agent' => user_agent })
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

    # Default scope: the slugs the panel presenter actually renders (with element
    # placeholders expanded) plus the hand-recovered extras; all_labels=true takes
    # everything the wiki gadget knows; only= takes an explicit list.
    elements = %w[fire water earth wind light dark]
    slugs = if ENV['only']
              ENV['only'].split(',')
            elsif all_labels
              mapping.keys.sort
            else
              # extras: badges beyond today's LINES that the panel may grow into
              # (odious frame lines, per-element reductions, spare AX labels).
              extras = %w[ex-stamina ex-enmity od-might od-stamina od-enmity bonus-elem-dmg
                          ax-exp-gain ax-rupie-gain ax-heal-cap ELEMENT-reduc]
              GridDamage::PanelPresenter::LINES.filter_map { |(_, _, _, slug, _)| slug } + manual.keys + extras
            end
    slugs = slugs.flat_map do |slug|
      slug.include?('ELEMENT') ? elements.map { |el| slug.sub('ELEMENT', el) } : [slug]
    end.uniq.sort
    unknown = slugs - mapping.keys
    puts "WARNING: no filename for: #{unknown.join(', ')}" if unknown.any?
    slugs &= mapping.keys

    puts "#{slugs.size} labels (storage=#{storage}, force=#{force})"
    failures = []
    slugs.each do |slug|
      results = Granblue::Downloaders::SkillLabelDownloader.new(
        slug, source_filename: mapping.fetch(slug), storage: storage, force: force
      ).download
      results.each do |lang, r|
        failures << [slug, lang, r[:error]] unless r[:success]
      end
      sleep(throttle) if throttle.positive? && results.values.any? { |r| !r[:skipped] }
    end

    puts failures.any? ? "#{failures.size} failure(s): #{failures.first(10).inspect}" : 'done'
    exit(1) if failures.any?
  end
end
