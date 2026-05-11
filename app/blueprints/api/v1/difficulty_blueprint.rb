# frozen_string_literal: true

module Api
  module V1
    class DifficultyBlueprint < ApiBlueprint
      fields :name, :slug, :description, :min_score, :max_score, :sort_order, :color

      # Host-relative URL (i.e. <prefix>/<key>?v=<timestamp>), not a literal S3
      # key. Versioned with updated_at so the URL changes on every upload,
      # busting any browser / CDN cache while the S3 object stays at a stable
      # path. Frontend prepends the configured S3/CDN host.
      field :image_url do |difficulty|
        next nil if difficulty.image_key.blank?

        if difficulty.respond_to?(:updated_at) && difficulty.updated_at
          "#{difficulty.image_key}?v=#{difficulty.updated_at.to_i}"
        else
          difficulty.image_key
        end
      end

      field :pending do |obj|
        obj.respond_to?(:pending?) && obj.pending?
      end
      field :pending_operation do |obj|
        obj.respond_to?(:pending_operation) ? obj.pending_operation : nil
      end
      field :draft_id do |obj|
        obj.respond_to?(:draft_id) ? obj.draft_id : nil
      end

      view :nested do
        fields :name, :slug, :color, :sort_order
      end

      view :list do
        include_view :nested
        fields :description, :min_score, :max_score
      end

      view :full do
        fields :created_at, :updated_at
      end
    end
  end
end
