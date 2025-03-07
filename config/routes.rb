Rails.application.routes.draw do
  use_doorkeeper do
    controllers tokens: 'tokens'
    skip_controllers :applications, :authorized_applications
  end

  path_prefix = Rails.env.production? ? '/v1' : '/api/v1'

  scope path: path_prefix, module: 'api/v1', defaults: { format: :json } do
    resources :parties, only: %i[index create update destroy]
    resources :users, only: %i[create update show]
    resources :grid_weapons, only: %i[update destroy]
    resources :grid_characters, only: %i[update destroy]
    resources :grid_summons, only: %i[update destroy]
    resources :weapons, only: :show
    resources :characters, only: :show
    resources :summons, only: :show
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
    post 'search/guidebooks', to: 'search#guidebooks'

    get 'jobs', to: 'jobs#all'

    get 'jobs/skills', to: 'job_skills#all'
    get 'jobs/:id', to: 'jobs#show'
    get 'jobs/:id/skills', to: 'job_skills#job'
    get 'jobs/:id/accessories', to: 'job_accessories#job'

    get 'guidebooks', to: 'guidebooks#all'

    get 'raids', to: 'raids#all'
    get 'raids/groups', to: 'raids#groups'
    get 'raids/:id', to: 'raids#show'
    get 'weapon_keys', to: 'weapon_keys#all'

    post 'characters', to: 'grid_characters#create'
    post 'characters/resolve', to: 'grid_characters#resolve'
    post 'characters/update_uncap', to: 'grid_characters#update_uncap_level'
    delete 'characters', to: 'grid_characters#destroy'

    post 'weapons', to: 'grid_weapons#create'
    post 'weapons/resolve', to: 'grid_weapons#resolve'
    post 'weapons/update_uncap', to: 'grid_weapons#update_uncap_level'
    delete 'weapons', to: 'grid_weapons#destroy'

    post 'summons', to: 'grid_summons#create'
    post 'summons/update_uncap', to: 'grid_summons#update_uncap_level'
    post 'summons/update_quick_summon', to: 'grid_summons#update_quick_summon'
    delete 'summons', to: 'grid_summons#destroy'

    delete 'favorites', to: 'favorites#destroy'
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
