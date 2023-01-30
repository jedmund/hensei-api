# Be sure to restart your server when you modify this file.

# Avoid CORS issues when API is called from the frontend app.
# Handle Cross-Origin Resource Sharing (CORS) in order to accept cross-origin AJAX requests.

# Read more: https://github.com/cyu/rack-cors

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    if Rails.env.production?
      origins %w[app.granblue.team hensei-web-production.up.railway.app]
    else
      origins %w[staging.granblue.team 127.0.0.1:1234]
    end

    resource "*",
             headers: :any,
             methods: [:get, :post, :put, :patch, :delete, :options, :head]
  end
end
