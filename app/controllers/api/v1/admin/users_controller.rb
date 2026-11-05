# frozen_string_literal: true

module Api
  module V1
    module Admin
      # User management for the Database's Users section. Admins only.
      #
      # Admins can set another user's role to user, curator or editor. The
      # admin role itself is only changed in the console: admins can't make
      # admins, demote admins, or change their own role here.
      #
      # The API enforces a new role on the next request (it reads the role
      # from the database). The web app caches the role in its session cookie
      # until the user signs in again or their token refreshes.
      class UsersController < Api::V1::ApiController
        include AdminCollection

        # Roles an admin may set from the Database
        ASSIGNABLE_ROLES = [1, 6, 7].freeze
        HISTORY_LIMIT = 50

        before_action :ensure_admin_role
        before_action :set_user, only: %i[show update_role]

        admin_collection User do
          # Email too: a search containing @ is kept out of the logs
          # (config/initializers/filter_parameter_logging.rb)
          search :username, :display_name, :email

          filter :role, type: :integer, facet: true
          flag :deletion_scheduled, 'users.deletion_scheduled_at IS NOT NULL'
          # Accounts linked on the profile
          flag :has_granblue_id, 'users.granblue_id IS NOT NULL'
          flag :has_youtube, "COALESCE(users.youtube, '') <> ''"
          flag :has_wiki_profile, "COALESCE(users.wiki_profile, '') <> ''"
          filter :created_at, type: :datetime

          sort :created_at, :username, :role
          default_sort '-created_at'

          # Email is searchable but not listed; it's in the detail only
          %i[username display_name role created_at deletion_scheduled_at
             granblue_id youtube wiki_profile].each { |name| field name }

          default_fields :username, :display_name, :role, :created_at, :deletion_scheduled_at

          etag_sources :access_changes
        end

        def index
          render_admin_collection
        end

        def show
          render json: detail(@user)
        end

        # PATCH /admin/users/:id/role { role: }
        def update_role
          return render_forbidden_response if @user.id == current_user.id
          return render_role_error('Admins are managed in the console') if @user.admin?

          role = Integer(params.require(:role), exception: false)
          return render_role_error("Role must be one of #{ASSIGNABLE_ROLES.join(', ')}") unless ASSIGNABLE_ROLES.include?(role)

          if role != @user.role
            User.transaction do
              @user.access_changes.create!(actor: current_user, kind: 'role', from_role: @user.role, to_role: role)
              @user.update!(role: role)
            end
          end

          render json: detail(@user.reload)
        end

        private

        def set_user
          @user = User.find_by(id: params[:id])
          render_not_found_response('user') unless @user
        end

        def render_role_error(message)
          render json: { error: message }, status: :unprocessable_content
        end

        def detail(user)
          {
            id: user.id,
            username: user.username,
            display_name: user.display_name,
            email: user.email,
            granblue_id: user.granblue_id,
            youtube: user.youtube,
            wiki_profile: user.wiki_profile,
            email_verified: user.email_verified,
            role: user.role,
            avatar: { picture: user.picture, element: user.element },
            created_at: user.created_at,
            deletion_scheduled_at: user.deletion_scheduled_at,
            party_count: user.parties.count,
            history: history(user)
          }
        end

        def history(user)
          user.access_changes.recent_first.limit(HISTORY_LIMIT).includes(:actor).map do |change|
            {
              id: change.id,
              kind: change.kind,
              from_role: change.from_role,
              to_role: change.to_role,
              actor: change.actor && { id: change.actor.id, username: change.actor.username },
              created_at: change.created_at
            }
          end
        end
      end
    end
  end
end
