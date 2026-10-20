# frozen_string_literal: true

# Attributes stored as the record's own `sources` rows instead of columns (D35).
#
#   source_attribute :wiki_raw, fetched_at: :wiki_raw_fetched_at
#
# defines wiki_raw / wiki_raw= (and the fetched_at pair), so code that reads or assigns
# them, update!(wiki_raw: …) included, keeps working while the text lives in `sources`:
#   - readers load the row on first use (or from a preloaded :sources association) and
#     return the value (parsed for JSON kinds);
#   - writers stage the value in memory; after_save writes it with Source.put (inside the
#     save's transaction), so an unsaved record (a refresh preview) builds from the staged
#     text and nothing is stored;
#   - #source_sha256(kind) is the stored (or staged) body's digest without loading a body.
#
# SQL scopes can't see these attributes: use with_source(kind) / without_source(kind).
module HasSources
  extend ActiveSupport::Concern

  included do
    has_many :sources, as: :owner, dependent: :delete_all, inverse_of: :owner

    after_save :write_staged_sources
  end

  class_methods do
    # attribute name → source kind
    def source_attributes
      @source_attributes ||= {}
    end

    def source_attribute(name, kind: name, fetched_at: nil)
      kind = kind.to_s
      source_attributes[name.to_s] = kind

      define_method(name) { source_value(kind) }
      define_method(:"#{name}=") { |value| stage_source(kind, value) }
      return unless fetched_at

      define_method(fetched_at) { source_fetched_at(kind) }
      define_method(:"#{fetched_at}=") { |time| stage_source_fetched_at(kind, time) }
    end

    # Loads records' source rows in one query. kinds: only those (a record then reads any
    # other kind as absent, so pass every kind the caller reads).
    def preload_sources(records, kinds: nil)
      scope = kinds ? Source.where(kind: Array(kinds).map(&:to_s)) : nil
      ActiveRecord::Associations::Preloader.new(records: Array(records), associations: :sources, scope: scope).call
      records
    end

    def with_source(kind)
      where(id: owned_sources(kind).select(:owner_id))
    end

    def without_source(kind)
      where.not(id: owned_sources(kind).select(:owner_id))
    end

    # The class's rows of kind.
    def owned_sources(kind)
      Source.where(owner_type: polymorphic_name, kind: kind.to_s, key: '')
    end
  end

  # Source kinds whose staged value the last save changed (cleared on the next save).
  def saved_source_changes
    @saved_source_changes || []
  end

  def source_sha256(kind)
    kind = kind.to_s
    if staged_sources.key?(kind)
      body = staged_sources[kind][:body]
      return body && Source.digest(body)
    end

    source_meta[kind]&.sha256
  end

  def reload(*)
    reset_sources
    super
  end

  private

  def staged_sources
    @staged_sources ||= {}
  end

  def source_value(kind)
    return staged_sources[kind][:value] if staged_sources.key?(kind) && staged_sources[kind].key?(:value)

    @source_values ||= {}
    return @source_values[kind] if @source_values.key?(kind)

    @source_values[kind] = source_row(kind)&.value
  end

  def source_fetched_at(kind)
    staged = staged_sources[kind]
    return staged[:fetched_at] if staged&.key?(:fetched_at)

    source_meta[kind]&.fetched_at
  end

  def stage_source(kind, value)
    staged = staged_sources[kind] ||= {}
    staged[:body] = Source.serialize(kind, value)
    staged[:value] = Source.deserialize(kind, staged[:body]) # as it reads back once stored
  end

  def stage_source_fetched_at(kind, time)
    (staged_sources[kind] ||= {})[:fetched_at] = Source.type_for_attribute('fetched_at').cast(time)
  end

  # The full row (body included).
  def source_row(kind)
    return sources.find { |source| source.kind == kind && source.key == '' } if association(:sources).loaded?
    return if new_record?

    sources.find_by(kind: kind, key: '')
  end

  # kind → row without its body (sha256, fetched_at), one query per record.
  def source_meta
    @source_meta ||= if association(:sources).loaded?
                       sources.select { |source| source.key == '' }.index_by(&:kind)
                     elsif new_record?
                       {}
                     else
                       Source.owned_by(self).where(key: '').without_body.index_by(&:kind)
                     end
  end

  def write_staged_sources
    changed = []
    staged_sources.each do |kind, staged|
      changed << kind if store_staged_source(kind, staged)&.changed?
    end
    @saved_source_changes = changed
    reset_sources
  end

  # → the Source::PutResult, or nil when only a fetch time was assigned.
  def store_staged_source(kind, staged)
    if staged.key?(:body)
      # No fetch time assigned: an edit, which keeps the stored fetch time.
      return Source.put_body(self, kind, staged[:body], fetched_at: staged[:fetched_at], skip_owner_hook: true)
    end

    # Only a fetch time was assigned: date the stored row, if there is one.
    Source.owned_by(self).where(kind: kind, key: '').update_all(fetched_at: staged[:fetched_at])
    nil
  end

  def reset_sources
    @staged_sources = {}
    @source_values = {}
    @source_meta = nil
    association(:sources).reset
  end
end
