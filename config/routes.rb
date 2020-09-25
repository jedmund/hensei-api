Rails.application.routes.draw do
    use_doorkeeper do
        controllers :tokens => 'tokens'
        skip_controllers :applications, :authorized_applications
    end
    
    namespace :api, defaults: { format: :json } do
        namespace :v1 do
            resources :parties, only: [:index, :create, :show, :destroy]
            resources :users, only: [:create, :show]
            resources :search, only: [:index]

            post 'weapons', to: 'grid_weapons#create'
            delete 'weapons', to: 'grid_weapons#destroy'
        end
    end
end
