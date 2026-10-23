# frozen_string_literal: true

# ar_internal_metadata times the character source migrations record (copy, sync).
module SourceMetadata
  def source_metadata_time(key)
    value = ActiveRecord::Base.connection.select_value(
      "SELECT value FROM ar_internal_metadata WHERE key = #{ActiveRecord::Base.connection.quote(key)}"
    )
    value && Time.iso8601(value.split.first)
  end

  def record_source_metadata(key, time, suffix = nil)
    conn = ActiveRecord::Base.connection
    value = [time.utc.iso8601(6), suffix].compact.join(' ')
    conn.execute("INSERT INTO ar_internal_metadata (key, value, created_at, updated_at) " \
                 "VALUES (#{conn.quote(key)}, #{conn.quote(value)}, now(), now()) " \
                 'ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value')
  end
end

RSpec.configure { |config| config.include SourceMetadata }
