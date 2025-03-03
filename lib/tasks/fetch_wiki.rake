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

        # 3) Save raw wiki text in the object record
        object.update!(wiki_raw: wiki_text)
        puts "Saved wiki data for #{object.name_en} (#{object.id})"
        count += 1
      rescue StandardError => e
        errors << { object_id: object.id, type: type, error: e.message }
        puts "Error fetching data for #{object.name_en}: #{e.message}"
      end
    end

    if errors.any?
      puts "#{errors.size} #{type.pluralize} had errors:"
      errors.each { |err| puts "  - #{err[:type]} ##{err[:object_id]} => #{err[:error]}" }
    else
      puts "Wiki data fetch complete for #{count} #{type.pluralize} with no errors!"
    end
  end
end
