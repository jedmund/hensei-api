Rails.application.routes.draw do
    use_doorkeeper do
        skip_controllers :applications, :authorized_applications
    end
    
    namespace :api, defaults: { format: :json } do
        namespace :v1 do
            resources :party, only: [:index, :create, :show, :destroy]
            resources :users, only: [:create, :show]
            resources :search, only: [:index]
        end
    end
end
