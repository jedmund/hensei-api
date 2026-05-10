# frozen_string_literal: true

module Api
  module V1
    class GridCharacterRolesController < ApiController
      ICON_MAX_DIMENSION = 128
      ICON_S3_PREFIX = 'images/grid_character_roles'

      before_action :doorkeeper_authorize!, only: %i[create update destroy reorder upload_icon]
      before_action :ensure_editor_role, only: %i[create update destroy reorder upload_icon]
      before_action :set_role, only: %i[show update destroy upload_icon]

      # GET /grid_character_roles
      def index
        roles = GridCharacterRole.order(:sort_order, :name_en)
        render json: GridCharacterRoleBlueprint.render(roles)
      end

      # GET /grid_character_roles/:id
      def show
        render json: GridCharacterRoleBlueprint.render(@role)
      end

      # POST /grid_character_roles
      def create
        role = GridCharacterRole.new(role_params)
        role.sort_order ||= next_sort_order

        if role.save
          render json: GridCharacterRoleBlueprint.render(role), status: :created
        else
          render_validation_error_response(role)
        end
      end

      # PUT /grid_character_roles/:id
      def update
        if @role.update(role_params)
          render json: GridCharacterRoleBlueprint.render(@role)
        else
          render_validation_error_response(@role)
        end
      end

      # DELETE /grid_character_roles/:id
      def destroy
        @role.destroy
        head :no_content
      rescue ActiveRecord::InvalidForeignKey
        render json: { error: 'Cannot delete a role that is in use. Reassign affected items first.' },
               status: :unprocessable_entity
      end

      # POST /grid_character_roles/reorder
      # Body: { roles: [{ id: <uuid>, sort_order: <int> }, ...] }
      def reorder
        entries = params[:roles]
        return render json: { error: 'roles array required' }, status: :unprocessable_entity if entries.blank?

        GridCharacterRole.transaction do
          entries.each do |entry|
            GridCharacterRole.find(entry[:id]).update!(sort_order: entry[:sort_order])
          end
        end

        render json: GridCharacterRoleBlueprint.render(GridCharacterRole.order(:sort_order, :name_en))
      end

      # POST /grid_character_roles/:id/upload_icon
      # Body: { image: <base64-png>, filename: <string> }
      def upload_icon
        image_data = params[:image]
        return render json: { error: 'No image data provided' }, status: :unprocessable_entity if image_data.blank?

        decoded = Base64.decode64(image_data)
        validation_error = validate_icon(decoded)
        return render json: { error: validation_error }, status: :unprocessable_entity if validation_error

        s3_key = "#{ICON_S3_PREFIX}/#{@role.id}.png"
        aws = AwsService.new
        aws.s3_client.put_object(
          bucket: aws.bucket,
          key: s3_key,
          body: StringIO.new(decoded),
          content_type: 'image/png',
          acl: 'public-read'
        )

        # The S3 object key stays at a stable path so re-uploads overwrite cleanly.
        # The stored icon_key carries a version query so the rendered URL changes on
        # every upload — the next role.updated_at bumps below and read paths bake
        # that timestamp into the public URL, busting browser/CDN cache.
        @role.update!(icon_key: s3_key)
        render json: GridCharacterRoleBlueprint.render(@role)
      end

      private

      def set_role
        @role = GridCharacterRole.find_by(id: params[:id])
        render_not_found_response('grid_character_role') unless @role
      end

      def role_params
        params.require(:grid_character_role).permit(:name_en, :name_jp, :sort_order)
      end

      def next_sort_order
        GridCharacterRole.maximum(:sort_order).to_i + 1
      end

      def ensure_editor_role
        return if current_user&.editor?

        Rails.logger.warn "[GRID_CHARACTER_ROLES] Unauthorized access attempt by user #{current_user&.id}"
        render json: { error: 'Unauthorized - Editor role required' }, status: :unauthorized
      end

      # Returns nil on valid icon, otherwise an error message string.
      def validate_icon(decoded)
        return 'Icon must be a PNG' unless decoded.start_with?("\x89PNG\r\n\x1A\n".b)

        Tempfile.create(['role_icon', '.png']) do |tmp|
          tmp.binmode
          tmp.write(decoded)
          tmp.flush

          image = MiniMagick::Image.open(tmp.path)
          return 'Icon must be a PNG' unless image.type == 'PNG'

          if image.width > ICON_MAX_DIMENSION || image.height > ICON_MAX_DIMENSION
            return "Icon must be #{ICON_MAX_DIMENSION}x#{ICON_MAX_DIMENSION} or smaller"
          end
        end

        nil
      rescue MiniMagick::Invalid
        'Icon could not be read as an image'
      end
    end
  end
end
