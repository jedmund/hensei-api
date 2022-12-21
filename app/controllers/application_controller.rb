# frozen_string_literal: true

class ApplicationController < ActionController::API
  # Not usually required for Rails 5 in API mode, but
  # necessary here because we're using RABL.
  include ActionView::Rendering
  append_view_path "#{Rails.root}/app/views"
end
