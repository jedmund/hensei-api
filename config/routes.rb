Rails.application.routes.draw do
    use_doorkeeper do
        controllers :tokens => 'tokens'
        skip_controllers :applications, :authorized_applications
    end

    namespace :api, defaults: { format: :json } do
        namespace :v1 do
            resources :parties, only: [:index, :create, :show, :destroy]
            resources :users, only: [:create, :show]

            post 'check/email', to: 'users#check_email'
            post 'check/username', to: 'users#check_username'

            get 'search/weapons', to: 'search#weapons'
            get 'search/summons', to: 'search#summons'

            post 'weapons', to: 'grid_weapons#create'
            delete 'weapons', to: 'grid_weapons#destroy'

            post 'summons', to: 'grid_summons#create'
            delete 'summons', to: 'grid_summons#destroy'
        end
    end
end
