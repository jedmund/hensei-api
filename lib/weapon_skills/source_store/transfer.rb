# frozen_string_literal: true

require "zlib"

module WeaponSkills
  module SourceStore
    # Copies stored sources between databases as gzipped JSON Lines, so a store filled once
    # by granblue:fetch_weapon_sources can seed another (prod) without refetching the wiki.
    #
    # Rows are matched by (weapon_id, kind, key). weapon_id is the weapon's UUID, which is
    # the same in every database restored from prod; each row also carries the weapon's
    # name, and a row whose weapon is missing or named differently is skipped and reported.
    # An existing row fetched later than the incoming one is kept.
    module Transfer
      FORMAT = 1
      BATCH = 100

      Plan = Struct.new(:inserts, :deletes, :weapon_updates, :counts, :problems, keyword_init: true)

      module_function

      def export(path)
        count = 0
        Zlib::GzipWriter.open(path.to_s) do |gz|
          gz.puts(JSON.generate("format" => FORMAT, "exported_at" => Time.current.utc.iso8601,
                                "rows" => WeaponSource.count))
          WeaponSource.includes(:weapon).find_each do |row|
            gz.puts(JSON.generate(
                      "weapon_id" => row.weapon_id, "weapon_granblue_id" => row.weapon&.granblue_id,
                      "weapon_name_en" => row.weapon&.name_en, "kind" => row.kind, "key" => row.key,
                      "page_kind" => row.page_kind, "fetched_at" => row.fetched_at.utc.iso8601(6),
                      "sha256" => row.sha256, "body" => row.body
                    ))
            count += 1
          end
        end
        count
      end

      def read(path)
        lines = Zlib::GzipReader.open(path.to_s) { |gz| gz.each_line.map { |l| JSON.parse(l) } }
        header = lines.shift or raise ArgumentError, "#{path} is empty"
        raise ArgumentError, "unsupported format #{header['format'].inspect}" unless header["format"] == FORMAT
        raise ArgumentError, "expected #{header['rows']} rows, read #{lines.size}" unless header["rows"] == lines.size

        [header, lines]
      end

      # What an import would do, without writing. → Plan
      def plan(rows)
        counts = Hash.new(0)
        problems = []
        weapons = Weapon.where(id: rows.filter_map { |r| r["weapon_id"] }.uniq).index_by(&:id)
        # Each weapon's page (Weapon#wiki_raw): [sha256, fetched_at], without the bodies. Its
        # titled row wins over a '' one (ordered last).
        pages = Weapon.owned_sources(:wiki_raw).where(owner_id: weapons.keys).without_body.order(:key)
                      .to_h { |row| [row.owner_id, [row.sha256, row.fetched_at]] }
        # Titles compare in Granblue::WikiTitle form, whichever form either side stored.
        existing = WeaponSource.pluck(:id, :weapon_id, :kind, :key, :fetched_at, :sha256)
                               .map { |id, w, kind, key, at, sha| [id, w, kind, Granblue::WikiTitle.normalize(key), at, sha] }
        by_identity = existing.index_by { |_id, weapon_id, kind, key, _, _| [weapon_id, kind, key] }
        inserts = []
        deletes = []
        weapon_updates = {}
        seen = Set.new

        # Newest first, so of two rows whose titles normalize alike the newer one wins.
        rows.sort_by { |r| r["fetched_at"] }.reverse_each do |r|
          key = Granblue::WikiTitle.normalize(r["key"])
          unless seen.add?([r["weapon_id"], r["kind"], key])
            counts[:duplicate_title] += 1
            next
          end

          sha = Digest::SHA256.hexdigest(r["body"].to_s)
          raise ArgumentError, "checksum mismatch for #{r['kind']} #{r['key']}" unless sha == r["sha256"]

          weapon = r["weapon_id"] && weapons[r["weapon_id"]]
          if r["weapon_id"] && weapon.nil?
            counts[:weapon_missing] += 1
            problems << "no weapon #{r['weapon_id']} (#{r['weapon_name_en']}): #{r['kind']} #{r['key']}"
            next
          end
          if weapon && weapon.name_en != r["weapon_name_en"]
            counts[:weapon_renamed] += 1
            problems << "weapon #{weapon.id} is #{weapon.name_en.inspect} here, #{r['weapon_name_en'].inspect} in the file"
            next
          end

          fetched_at = Time.iso8601(r["fetched_at"])
          current = by_identity[[r["weapon_id"], r["kind"], key]]
          if current && current[5] == sha
            counts[:unchanged] += 1
          elsif current && current[4] >= fetched_at
            counts[:kept_newer] += 1
            next
          else
            counts[current ? :replaced : :added] += 1
            deletes << current[0] if current
            inserts << { weapon_id: r["weapon_id"], kind: r["kind"], key: key, body: r["body"], sha256: sha,
                         page_kind: r["page_kind"], fetched_at: fetched_at }
            # A weapon's page under another title (it was renamed or redirected) is replaced.
            if weapon && r["kind"] == "wiki_raw"
              existing.each do |id, weapon_id, kind, stored_key, at, _|
                deletes << id if weapon_id == weapon.id && kind == "wiki_raw" && stored_key != key && at < fetched_at
              end
            end
          end

          # wiki_raw_fetched_at records when the page was last checked, so it moves up to
          # the stored fetch even when the text is the same.
          next unless weapon && r["kind"] == "wiki_raw"

          page_sha, page_fetched_at = pages[weapon.id]
          next if page_fetched_at && page_fetched_at >= fetched_at

          weapon_updates[weapon.id] = { wiki_raw: r["body"], fetched_at: fetched_at, wiki_en: key }
          counts[:weapon_checked] += 1
          counts[:weapon_pages] += 1 if page_sha != sha
          counts[:weapon_renamed_pages] += 1 if weapon.wiki_en != key
        end
        Plan.new(inserts: inserts, deletes: deletes.uniq, weapon_updates: weapon_updates, counts: counts,
                 problems: problems)
      end

      # Applies a plan in one transaction. The stored page is the weapon's page (Weapon#wiki_raw),
      # as after a fetch: a page stored without a fetch (key '') goes, and the page's fetch time
      # moves up to the file's.
      def apply(plan)
        now = Time.current
        ActiveRecord::Base.transaction do
          WeaponSource.where(id: plan.deletes).delete_all if plan.deletes.any?
          plan.inserts.each_slice(BATCH) do |batch|
            WeaponSource.insert_all!(batch.map { |row| stored_row(row).merge(created_at: now, updated_at: now) })
          end
          Weapon.where(id: plan.weapon_updates.keys).select(:id).find_each do |weapon|
            attrs = plan.weapon_updates.fetch(weapon.id)
            Weapon.where(id: weapon.id).update_all(wiki_en: attrs[:wiki_en])
            ::Source.where(owner_type: Weapon.polymorphic_name, owner_id: weapon.id, kind: "wiki_raw", key: "").delete_all
            WeaponSource.where(weapon_id: weapon.id, kind: "wiki_raw", key: attrs[:wiki_en])
                        .where(fetched_at: ...attrs[:fetched_at]).update_all(fetched_at: attrs[:fetched_at])
          end
        end
      end

      # A planned row as a `sources` row: the weapon is its owner.
      def stored_row(row)
        weapon_id = row[:weapon_id]
        row.except(:weapon_id).merge(owner_id: weapon_id, owner_type: weapon_id && Weapon.polymorphic_name)
      end
    end
  end
end
