Rails.application.routes.draw do
  use_doorkeeper do
    controllers tokens: 'tokens'
    skip_controllers :applications, :authorized_applications
  end

  path_prefix = Rails.env.production? ? '/v1' : '/api/v1'

  scope path: path_prefix, module: 'api/v1', defaults: { format: :json } do
    resources :parties, only: %i[index create update destroy]
    get 'users/me', to: 'users#me'
    resources :users, only: %i[create update show]
    resources :grid_weapons, only: %i[create update destroy]
    resources :grid_characters, only: %i[create update destroy]
    resources :grid_summons, only: %i[create update destroy]
    resources :weapons, only: %i[show create update] do
      collection do
        get 'validate/:granblue_id', action: :validate, as: :validate
        post 'batch_preview'
      end
      member do
        post 'download_image'
        post 'download_images'
        get 'download_status'
        get 'raw'
        post 'fetch_wiki'
      end
    end
    resources :characters, only: %i[show create update] do
      collection do
        get 'validate/:granblue_id', action: :validate, as: :validate
        post 'batch_preview'
      end
      member do
        post 'download_image'
        post 'download_images'
        get 'download_status'
        get 'raw'
        post 'fetch_wiki'
      end
    end
    resources :summons, only: %i[show create update] do
      collection do
        get 'validate/:granblue_id', action: :validate, as: :validate
        post 'batch_preview'
      end
      member do
        post 'download_image'
        post 'download_images'
        get 'download_status'
        get 'raw'
        post 'fetch_wiki'
      end
    end
    resources :favorites, only: [:create]

    get 'version', to: 'api#version'

    post 'import', to: 'import#create'
    post 'import/weapons', to: 'import#weapons'
    post 'import/summons', to: 'import#summons'
    post 'import/characters', to: 'import#characters'

    get 'users/info/:id', to: 'users#info'

    get 'parties/favorites', to: 'parties#favorites'
    get 'parties/:id', to: 'parties#show'
    get 'parties/:id/preview', to: 'parties#preview'
    get 'parties/:id/preview_status', to: 'parties#preview_status'
    post 'parties/:id/regenerate_preview', to: 'parties#regenerate_preview'
    post 'parties/:id/remix', to: 'parties#remix'

    # Party shares
    resources :parties, only: [] do
      resources :shares, controller: 'party_shares', only: [:index, :create, :destroy]
    end

    put 'parties/:id/jobs', to: 'jobs#update_job'
    put 'parties/:id/job_skills', to: 'jobs#update_job_skills'
    delete 'parties/:id/job_skills', to: 'jobs#destroy_job_skill'

    post 'check/email', to: 'users#check_email'
    post 'check/username', to: 'users#check_username'

    post 'search', to: 'search#all'
    post 'search/characters', to: 'search#characters'
    post 'search/weapons', to: 'search#weapons'
    post 'search/summons', to: 'search#summons'
    post 'search/job_skills', to: 'search#job_skills'
    post 'search/jobs', to: 'search#jobs'
    post 'search/guidebooks', to: 'search#guidebooks'
    get 'search/suggestions', to: 'search#suggestions'

    get 'jobs', to: 'jobs#all'
    post 'jobs', to: 'jobs#create'

    get 'jobs/skills', to: 'job_skills#all'
    get 'jobs/:id', to: 'jobs#show'
    put 'jobs/:id', to: 'jobs#update'
    get 'jobs/:id/skills', to: 'job_skills#job'
    get 'jobs/:id/emp_skills', to: 'job_skills#emp'
    post 'jobs/:job_id/skills', to: 'job_skills#create'
    put 'jobs/:job_id/skills/:id', to: 'job_skills#update'
    delete 'jobs/:job_id/skills/:id', to: 'job_skills#destroy'
    post 'jobs/:job_id/skills/:id/download_image', to: 'job_skills#download_image'
    get 'jobs/:id/accessories', to: 'job_accessories#job'

    # Job Accessories (database management)
    resources :job_accessories, only: %i[index show create update destroy]

    get 'characters/:id/related', to: 'characters#related'

    get 'guidebooks', to: 'guidebooks#all'

    # Raids and RaidGroups
    resources :raid_groups, only: %i[index show create update destroy]
    resources :raids, only: %i[index show create update destroy] do
      member do
        post :download_image
        post :download_images
        get :download_status
      end
    end
    get 'raids/groups', to: 'raids#groups' # Legacy endpoint

    get 'weapon_keys', to: 'weapon_keys#all'

    resources :weapon_series, only: %i[index show create update destroy]
    resources :character_series, only: %i[index show create update destroy]
    resources :summon_series, only: %i[index show create update destroy]

    # Artifacts (read-only reference data)
    resources :artifacts, only: %i[index show] do
      collection do
        post :grade
      end
      member do
        post :download_image
        post :download_images
        get :download_status
      end
    end
    resources :artifact_skills, only: %i[index show update] do
      collection do
        get 'for_slot/:slot', action: :for_slot, as: :for_slot
      end
    end
    resources :weapon_stat_modifiers, only: %i[index show]
    resources :weapon_skill_data, only: %i[index show]
    resources :weapon_skill_boost_types, only: %i[index show]

    # Grid artifacts
    resources :grid_artifacts, only: %i[create update destroy] do
      member do
        post :sync
      end
    end

    # Sync endpoints for grid items
    post 'grid_characters/:id/sync', to: 'grid_characters#sync'
    post 'grid_weapons/:id/sync', to: 'grid_weapons#sync'
    post 'grid_summons/:id/sync', to: 'grid_summons#sync'
    post 'parties/:id/sync_all', to: 'parties#sync_all'
    post 'parties/:id/unlink_collection', to: 'parties#unlink_collection'

    # Grid endpoints - new prefixed versions
    post 'grid_characters/resolve', to: 'grid_characters#resolve'
    post 'grid_characters/update_uncap', to: 'grid_characters#update_uncap_level'
    delete 'grid_characters', to: 'grid_characters#destroy'

    post 'grid_weapons/resolve', to: 'grid_weapons#resolve'
    post 'grid_weapons/update_uncap', to: 'grid_weapons#update_uncap_level'
    delete 'grid_weapons', to: 'grid_weapons#destroy'

    post 'grid_summons/update_uncap', to: 'grid_summons#update_uncap_level'
    post 'grid_summons/update_quick_summon', to: 'grid_summons#update_quick_summon'
    delete 'grid_summons', to: 'grid_summons#destroy'

    # Drag-drop API endpoints
    put 'parties/:party_id/grid_weapons/:id/position', to: 'grid_weapons#update_position'
    post 'parties/:party_id/grid_weapons/swap', to: 'grid_weapons#swap'

    put 'parties/:party_id/grid_characters/:id/position', to: 'grid_characters#update_position'
    post 'parties/:party_id/grid_characters/swap', to: 'grid_characters#swap'

    put 'parties/:party_id/grid_summons/:id/position', to: 'grid_summons#update_position'
    post 'parties/:party_id/grid_summons/swap', to: 'grid_summons#swap'

    post 'parties/:id/grid_update', to: 'parties#grid_update'

    delete 'favorites', to: 'favorites#destroy'

    # Crews - current user's crew (no ID needed)
    resource :crew, only: %i[show update], controller: 'crews' do
      member do
        get :members
        get :roster
        get :shared_parties
        post :leave
      end
    end

    # Crews - create and manage by ID
    resources :crews, only: %i[create] do
      member do
        post :transfer_captain
      end

      resources :memberships, controller: 'crew_memberships', only: %i[update destroy] do
        collection do
          get 'by_user/:user_id', action: :history, as: :history
        end
        member do
          post :promote
          post :demote
        end
      end

      resources :invitations, controller: 'crew_invitations', only: %i[index create]

      resources :phantom_players, only: %i[index show create update destroy] do
        collection do
          post :bulk_create
        end
        member do
          post :assign
          post :confirm_claim
          post :decline_claim
        end
      end
    end

    # Invitations for current user
    resources :invitations, controller: 'crew_invitations', only: [] do
      collection do
        get :pending
      end
      member do
        post :accept
        post :reject
      end
    end

    # Pending phantom claims for current user (outside crew context)
    get :pending_phantom_claims, to: 'phantom_claims#index'

    # GW Events (public read, admin write)
    resources :gw_events, only: %i[index show create update] do
      member do
        post :participations, to: 'crew_gw_participations#create'
      end
    end

    # Current user's crew GW participations
    scope :crew do
      resources :gw_participations, controller: 'crew_gw_participations', only: %i[index show update] do
        resources :crew_scores, controller: 'gw_crew_scores', only: %i[create update destroy]
        resources :individual_scores, controller: 'gw_individual_scores', only: %i[create update destroy] do
          collection do
            post :batch
          end
        end
      end
      get 'gw_participations/by_event/:event_id', to: 'crew_gw_participations#by_event', as: :gw_participation_by_event

      # Create individual scores by event (auto-creates participation if needed)
      post 'gw_events/:gw_event_id/individual_scores', to: 'gw_individual_scores#create_by_event'
      post 'gw_events/:gw_event_id/individual_scores/batch', to: 'gw_individual_scores#batch_by_event'

      # Member/phantom GW score history
      get 'memberships/:id/gw_scores', to: 'crew_memberships#gw_scores'
      get 'phantom_players/:id/gw_scores', to: 'phantom_players#gw_scores'
    end

    # Reading collections - works for any user with privacy check
    scope 'users/:user_id' do
      namespace :collection do
        get :counts, controller: '/api/v1/collection'
        get :granblue_ids, controller: '/api/v1/collection'
        get :game_ids, controller: '/api/v1/collection'
        post :item_count, controller: '/api/v1/collection'
        resources :characters, only: [:index, :show], controller: '/api/v1/collection_characters'
        resources :weapons, only: [:index, :show], controller: '/api/v1/collection_weapons'
        resources :summons, only: [:index, :show], controller: '/api/v1/collection_summons'
        resources :artifacts, only: [:index, :show], controller: '/api/v1/collection_artifacts'
      end
    end

    # Writing to collections - requires auth, operates on current_user
    namespace :collection do
      resources :characters, only: [:create, :update, :destroy], controller: '/api/v1/collection_characters' do
        collection do
          post :batch
          delete :batch_destroy
          post :import
        end
      end
      resources :weapons, only: [:create, :update, :destroy], controller: '/api/v1/collection_weapons' do
        collection do
          post :batch
          delete :batch_destroy
          post :import
          post :preview_sync
          post :check_conflicts
        end
      end
      resources :summons, only: [:create, :update, :destroy], controller: '/api/v1/collection_summons' do
        collection do
          post :batch
          delete :batch_destroy
          post :import
          post :preview_sync
          post :check_conflicts
        end
      end
      resources :job_accessories, controller: '/api/v1/collection_job_accessories',
                only: [:index, :show, :create, :destroy]
      resources :artifacts, only: [:create, :update, :destroy], controller: '/api/v1/collection_artifacts' do
        collection do
          post :batch
          delete :batch_destroy
          post :import
          post :preview_sync
        end
      end
    end
  end

  if Rails.env.development?
    get '/party-previews/*filename', to: proc { |env|
      filename = env['action_dispatch.request.path_parameters'][:filename]
      path = Rails.root.join('storage', 'party-previews', filename)

      if File.exist?(path)
        [200, {
          'Content-Type' => 'image/png',
          'Cache-Control' => 'no-cache' # Prevent caching during development
        }, [File.read(path)]]
      else
        [404, { 'Content-Type' => 'text/plain' }, ['Preview not found']]
      end
    }
  end
end
