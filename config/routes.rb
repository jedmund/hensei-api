Rails.application.routes.draw do
  use_doorkeeper do
    controllers tokens: 'tokens'
    skip_controllers :applications, :authorized_applications
  end

  namespace :api, defaults: { format: :json } do
    namespace :v1 do
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

      get 'users/info/:id', to: 'users#info'

      get 'parties/favorites', to: 'parties#favorites'
      get 'parties/:id', to: 'parties#show'
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
  end
end
