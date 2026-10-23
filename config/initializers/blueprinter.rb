# frozen_string_literal: true

require 'oj'

# JSON generator for Blueprinter. Oj in :rails mode produces the same output
# as Rails' encoder (`render json: hash`): ISO 8601 timestamps, including ones
# nested inside block fields, and HTML-safe escaping. Plain Oj.generate wrote
# times with Time#to_s ("2026-10-01 12:34:56 UTC"), which Safari can't parse.
module BlueprinterJson
  def self.generate(object)
    Oj.dump(object, mode: :rails)
  end
end

Blueprinter.configure do |config|
  config.generator = BlueprinterJson
  config.sort_fields_by = :definition
end
