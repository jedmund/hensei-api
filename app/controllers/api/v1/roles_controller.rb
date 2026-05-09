# frozen_string_literal: true

module Api
  module V1
    class RolesController < ApiController
      ICON_MAX_DIMENSION = 128
      ICON_S3_PREFIX = 'images/roles'

      before_action :doorkeeper_authorize!, only: %i[create update destroy reorder upload_icon]
      before_action :ensure_editor_role, only: %i[create update destroy reorder upload_icon]
      before_action :set_role, only: %i[show update destroy upload_icon]

      # GET /roles
      def index
        roles = Role.all
        roles = roles.for_slot(params[:slot_type]) if params[:slot_type].present?
        roles = roles.order(:sort_order, :name_en)

        render json: RoleBlueprint.render(roles)
      end

      # GET /roles/:id
      def show
        render json: RoleBlueprint.render(@role)
      end

      # POST /roles
      def create
        role = Role.new(role_params)
        role.sort_order ||= next_sort_order(role.slot_type)

        if role.save
          render json: RoleBlueprint.render(role), status: :created
        else
          render_validation_error_response(role)
        end
      end

      # PUT /roles/:id
      def update
        if @role.update(role_params)
          render json: RoleBlueprint.render(@role)
        else
          render_validation_error_response(@role)
        end
      end

      # DELETE /roles/:id
      def destroy
        @role.destroy
        head :no_content
      end

      # POST /roles/reorder
      # Body: { roles: [{ id: <uuid>, sort_order: <int> }, ...] }
      def reorder
        entries = params[:roles]
        return render json: { error: 'roles array required' }, status: :unprocessable_entity if entries.blank?

        Role.transaction do
          entries.each do |entry|
            Role.find(entry[:id]).update!(sort_order: entry[:sort_order])
          end
        end

        render json: RoleBlueprint.render(Role.order(:sort_order, :name_en))
      end

      # POST /roles/:id/upload_icon
      # Body: { image: <base64-png>, filename: <string> }
      def upload_icon
        image_data = params[:image]
        return render json: { error: 'No image data provided' }, status: :unprocessable_entity if image_data.blank?

        decoded = Base64.decode64(image_data)
        validation_error = validate_icon(decoded)
        return render json: { error: validation_error }, status: :unprocessable_entity if validation_error

        s3_key = "#{ICON_S3_PREFIX}/#{@role.id}.png"
        AwsService.new.s3_client.put_object(
          bucket: AwsService.new.bucket,
          key: s3_key,
          body: StringIO.new(decoded),
          content_type: 'image/png',
          acl: 'public-read'
        )

        @role.update!(icon_key: s3_key)
        render json: RoleBlueprint.render(@role)
      end

      private

      def set_role
        @role = Role.find_by(id: params[:id])
        render_not_found_response('role') unless @role
      end

      def role_params
        params.require(:role).permit(:name_en, :name_jp, :slot_type, :sort_order)
      end

      def next_sort_order(slot_type)
        Role.for_slot(slot_type).maximum(:sort_order).to_i + 1
      end

      def ensure_editor_role
        return if current_user&.editor?

        Rails.logger.warn "[ROLES] Unauthorized access attempt by user #{current_user&.id}"
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
