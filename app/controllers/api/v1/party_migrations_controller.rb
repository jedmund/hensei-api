# frozen_string_literal: true

module Api
  module V1
    # Claiming anonymous parties for the signed-in user (PartyMigration).
    #
    # POST /parties/migrate and POST /parties/preview_migrate take
    # `parties: [{ shortcode, edit_key }]`, or use the user's deposited keys
    # when it's absent.
    class PartyMigrationsController < Api::V1::ApiController
      TOO_MANY_PARTIES = 'Too many parties (max 100)'

      before_action :require_user!
      before_action :set_migration

      # POST /parties/migrate
      def create
        render json: @migration.claim!, status: :ok
      end

      # POST /parties/preview_migrate
      def preview
        rows = @migration.preview
        # Each party renders on its own, so their stickers are looked up
        # together here. Without current_user so `favorited` keeps its
        # signed-out value.
        sticker_options = PartyStickerSummary.batch_options(rows.filter_map { |row| row[:party] }, current_user)

        parties = rows.map do |row|
          party = row[:party] && PartyBlueprint.render_as_hash(row[:party], view: :preview, **sticker_options)
          { party: party, status: row[:status] }
        end

        render json: { parties: parties }, status: :ok
      end

      private

      def require_user!
        raise Api::V1::UnauthorizedError unless current_user
      end

      def set_migration
        @migration = PartyMigration.new(current_user, entry_params, admin_mode: admin_mode)
        render json: { error: TOO_MANY_PARTIES }, status: :unprocessable_content if @migration.too_many?
      end

      def entry_params
        params.expect(parties: [%i[shortcode edit_key]]) if params[:parties].present?
      end
    end
  end
end
