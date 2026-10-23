# frozen_string_literal: true

module Sources
  # Removes `sources` rows whose owner is gone (a record deleted with SQL rather than destroyed;
  # `sources` is polymorphic, so no foreign key does it) and, for a weapon, an untitled page left
  # beside its titled one (Weapon#wiki_raw). Shared rows stay. → { label => rows removed }
  #
  #   bin/rails granblue:remove_orphan_sources
  class OrphanCleanup
    OWNERS = [Character, Weapon, Summon].freeze

    def call
      removed = OWNERS.to_h do |model|
        [model.name, Source.where(owner_type: model.polymorphic_name).where.not(owner_id: model.select(:id)).delete_all]
      end
      titled = Source.where(owner_type: 'Weapon', kind: 'wiki_raw').where.not(key: '').select(:owner_id)
      removed['Weapon untitled pages'] = Source.where(owner_type: 'Weapon', kind: 'wiki_raw', key: '', owner_id: titled)
                                               .delete_all
      removed
    end
  end
end
