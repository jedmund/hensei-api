# frozen_string_literal: true

require 'oj' # you can skip this if OJ has already been required.

Blueprinter.configure do |config|
  config.generator = Oj # default is JSON
  config.sort_fields_by = :definition
end
