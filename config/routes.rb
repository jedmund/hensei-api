Rails.application.routes.draw do
    use_doorkeeper do
        controllers :tokens => 'tokens'
        skip_controllers :applications, :authorized_applications
    end

    namespace :api, defaults: { format: :json } do
        namespace :v1 do
            resources :parties, only: [:index, :create, :update, :destroy]
            resources :users, only: [:create, :show]
            resources :grid_weapons, only: [:update]
            resources :favorites, only: [:create]

            get 'parties/favorites', to: 'parties#favorites'
            get 'parties/:id', to: 'parties#show'
            get 'parties/:id/weapons', to: 'parties#weapons'
            get 'parties/:id/summons', to: 'parties#summons'
            get 'parties/:id/characters', to: 'parties#characters'
            get 'parties/all', to: 'parties#all'

            post 'check/email', to: 'users#check_email'
            post 'check/username', to: 'users#check_username'

            get 'search/characters', to: 'search#characters'
            get 'search/weapons', to: 'search#weapons'
            get 'search/summons', to: 'search#summons'

            get 'raids', to: 'raids#all'
            get 'weapon_keys', to: 'weapon_keys#all'

            post 'characters', to: 'grid_characters#create'
            post 'characters/update_uncap', to: 'grid_characters#update_uncap_level'
            delete 'characters', to: 'grid_characters#destroy'

            post 'weapons', to: 'grid_weapons#create'
            post 'weapons/update_uncap', to: 'grid_weapons#update_uncap_level'
            delete 'weapons', to: 'grid_weapons#destroy'

            post 'summons', to: 'grid_summons#create'
            post 'summons/update_uncap', to: 'grid_summons#update_uncap_level'
            delete 'summons', to: 'grid_summons#destroy'

            delete 'favorites', to: 'favorites#destroy'
        end
    end
end
