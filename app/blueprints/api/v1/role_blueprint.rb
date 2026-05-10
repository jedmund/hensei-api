# frozen_string_literal: true

module Api
  module V1
    class RoleBlueprint < ApiBlueprint
      fields :id, :name_en, :name_jp, :slot_type, :sort_order

      # icon_key is the S3 path with a version query appended so re-uploads bust
      # browser/CDN caches. The actual S3 object lives at the un-versioned path;
      # query strings are ignored by S3 but key the public URL on the CDN.
      field :icon_key do |role|
        if role.icon_key.present?
          "#{role.icon_key}?v=#{role.updated_at.to_i}"
        end
      end
    end
  end
end
