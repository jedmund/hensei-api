# frozen_string_literal: true

# class CacheFreeLogger < ActiveSupport::Logger
#   def add(severity, message = nil, progname = nil, &block)
#     return true if progname&.include? 'CACHE'
#
#     super
#   end
# end
#
ActiveRecord::Base.logger = Logger.new(STDOUT)
# ActiveRecord::Base.logger.level = 1
