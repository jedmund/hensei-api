# frozen_string_literal: true

# Echo SQL to STDOUT in development only. In other environments ActiveRecord
# uses Rails.logger and its configured level, so production doesn't log SQL
# (which includes raw OAuth tokens in the token lookup query).
ActiveRecord::Base.logger = Logger.new($stdout) if Rails.env.development?
