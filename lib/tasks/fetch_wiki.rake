namespace :granblue do
  desc <<~DESC
    Fetch and store raw wiki data for objects (Character, Weapon, Summon).

    Usage:
      rake granblue:fetch_wiki_data                     # Fetch all Characters (default)
      rake granblue:fetch_wiki_data type=Weapon         # Fetch all Weapons
      rake granblue:fetch_wiki_data type=Summon         # Fetch all Summons
      rake granblue:fetch_wiki_data type=Character id=5 # Fetch specific Character by ID
      rake granblue:fetch_wiki_data force=true          # Force re-download even if data exists
  DESC
  task fetch_wiki_data: :environment do
    # Get parameters from environment
    type = (ENV['type'] || 'Character').classify
    id = ENV['id']
    force = ENV['force'] == 'true'
    delay = (ENV['delay'].presence || '0.5').to_f # be respectful: throttle between wiki requests

    # Validate object type
    valid_types = %w[Character Weapon Summon]
    unless valid_types.include?(type)
      puts "Error: Invalid type '#{type}'. Must be one of: #{valid_types.join(', ')}"
      exit 1
    end

    # Get the class from the type string
    klass = type.constantize

    # Setup query - either all objects or specific one
    query = id.present? ? klass.where(granblue_id: id) : klass.all

    errors = []
    count = 0

    query.find_each do |object|
      # Skip objects that already have wiki_raw if force is not set
      if object.wiki_raw.present? && !force
        puts "Skipping #{object.name_en} (already has wiki_raw)."
        next
      end

      # If the object doesn't have a wiki page specified, skip
      if object.wiki_en.blank?
        puts "Skipping #{object.name_en} (no wiki_en set)."
        next
      end

      begin
        # 1) Fetch raw wikitext from the wiki
        wiki_text = Granblue::Parsers::Wiki.new.fetch(object.wiki_en)

        # 2) Check if the page is a redirect
        redirect_match = wiki_text.match(/#REDIRECT \[\[(.*?)\]\]/)
        if redirect_match
          redirect_target = redirect_match[1]
          # Update object to new wiki_en so we don't keep fetching the old page
          object.update!(wiki_en: redirect_target)
          # Fetch again with the new page name
          wiki_text = Granblue::Parsers::Wiki.new.fetch(redirect_target)
        end
        puts wiki_text

        # 3) Save raw wiki text in the object record (stamp fetch time on
        #    types that track it — currently only Weapon).
        attrs = { wiki_raw: wiki_text }
        attrs[:wiki_raw_fetched_at] = Time.current if object.respond_to?(:wiki_raw_fetched_at)
        object.update!(attrs)
        puts "Saved wiki data for #{object.name_en} (#{object.id})"
        count += 1
      rescue StandardError => e
        errors << { object_id: object.id, type: type, error: e.message }
        puts "Error fetching data for #{object.name_en}: #{e.message}"
      end

      sleep(delay)
    end

    if errors.any?
      puts "#{errors.size} #{type.pluralize} had errors:"
      errors.each { |err| puts "  - #{err[:type]} ##{err[:object_id]} => #{err[:error]}" }
    else
      puts "Wiki data fetch complete for #{count} #{type.pluralize} with no errors!"
    end
  end

  desc <<~DESC
    Re-fetch wiki_raw for Weapons that are missing it or stale — i.e. the wiki
    page likely changed since we last fetched (new uncap/transcendence). Stale =
    wiki_raw blank, never stamped, or latest_date newer than wiki_raw_fetched_at.

    Usage:
      rake granblue:refresh_stale_wiki_data            # all missing/stale weapons
      rake granblue:refresh_stale_wiki_data days=30    # also any weapon updated in last 30 days
      rake granblue:refresh_stale_wiki_data limit=50   # cap the batch
      rake granblue:refresh_stale_wiki_data delay=1.0  # seconds between requests (default 0.5)
  DESC
  task refresh_stale_wiki_data: :environment do
    days  = ENV['days'].presence&.to_i
    limit = ENV['limit'].presence&.to_i
    delay = (ENV['delay'].presence || '0.5').to_f

    base = Weapon.where.not(wiki_en: [nil, ''])
    stale = base.where(
      "wiki_raw IS NULL OR wiki_raw = '' OR wiki_raw_fetched_at IS NULL OR latest_date > wiki_raw_fetched_at"
    )
    stale = stale.or(base.where('latest_date > ?', days.days.ago.to_date)) if days

    weapons = (limit ? stale.limit(limit) : stale).to_a
    total = weapons.size
    puts "Refreshing wiki_raw for #{total} weapons (#{delay}s between requests)..."

    errors = []
    count = 0
    weapons.each_with_index do |weapon, i|
      begin
        wiki_text = Granblue::Parsers::Wiki.new.fetch(weapon.wiki_en)
        if (redirect = wiki_text.match(/#REDIRECT \[\[(.*?)\]\]/))
          weapon.update!(wiki_en: redirect[1])
          wiki_text = Granblue::Parsers::Wiki.new.fetch(redirect[1])
        end
        weapon.update!(wiki_raw: wiki_text, wiki_raw_fetched_at: Time.current)
        count += 1
        puts "  (#{i + 1}/#{total}) #{weapon.name_en}"
      rescue StandardError => e
        errors << "#{weapon.granblue_id} (#{weapon.name_en}): #{e.message}"
        puts "  (#{i + 1}/#{total}) ERROR #{weapon.name_en}: #{e.message}"
      end
      sleep delay
    end

    puts "Refreshed #{count}/#{total} weapons. Errors: #{errors.size}"
    errors.each { |e| puts "  - #{e}" }
  end
end
