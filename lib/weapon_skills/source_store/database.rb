# frozen_string_literal: true

module WeaponSkills
  module SourceStore
    # The weapon_sources table as a SourceStore. A lookup matches (kind, key) whatever the
    # owning weapon is, and returns the newest fetch: a page several weapons follow (a
    # shared base page, say) is stored once per weapon, with the same body from one run.
    # Keys are page titles in Granblue::WikiTitle form.
    class Database
      include Interface

      def fetch(kind, key)
        key = Granblue::WikiTitle.normalize(key).to_s
        row = WeaponSource.where(kind: kind.to_s, key: key).order(fetched_at: :desc).first
        raise SourceMissing.new(kind, key) unless row

        row.to_source
      end

      # weapon_id: the weapon this source belongs to; nil for pages no weapon owns.
      def put(kind, key, body, page_kind: nil, fetched_at: Time.current, weapon_id: nil)
        raise ArgumentError, "unknown source kind #{kind}" unless KINDS.include?(kind.to_s)

        key = Granblue::WikiTitle.normalize(key).to_s
        row = WeaponSource.find_or_initialize_by(weapon_id: weapon_id, kind: kind.to_s, key: key)
        row.update!(body: body.to_s, page_kind: page_kind&.to_s, fetched_at: fetched_at)
        row.to_source
      end
    end
  end
end
