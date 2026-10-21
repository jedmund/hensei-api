# frozen_string_literal: true

# A fetched input, stored once (D34/D35): a wiki page, a game payload or a shared list.
# Only the current body is kept, with its sha256; no history.
#
#   - Owned rows belong to a record (owner_type/owner_id) and are unique per
#     (owner, kind, key); a record's single source of a kind uses key ''.
#   - Shared rows have no owner and are unique per (kind, key).
#
# Bodies are text. JSON kinds hold canonical JSON (object keys sorted, recursively), so
# sha256 is the digest of exactly what is stored, a payload that only reorders its keys
# isn't a change, and #value parses it back. A blank value is never stored: putting one
# removes the row.
#
#   Source.put(character, :game_raw_en, payload, fetched_at: Time.current) # → PutResult
#   Source.read(character, :game_raw_en)                                    # → Hash or nil
#   Source.fetch(nil, :wiki_status_list, key: 'Module:StatusList')          # → Source or nil
#
# An owner class can react to a change of one of its sources by defining
#   self.source_change_hook?(kind)  → called when the row is written (true to be told), and
#   self.source_changed(owner_id, kind) → called after the commit.
# Character uses it to queue the skill build.
class Source < ApplicationRecord
  # kind → body format
  KINDS = {
    'wiki_raw' => :text,
    'wiki_raw_jp' => :text,
    'game_raw_en' => :json,
    'game_raw_jp' => :json,
    'wiki_status_list' => :text,
    # Curated Japanese skill text for a character row no fetched page covers (D38).
    'jp_skill_text' => :json
  }.freeze

  # What a put did: created | changed | unchanged (only fetched_at moved) | removed (blank
  # value, a row was deleted) | absent (blank value, nothing stored).
  PutResult = Struct.new(:status, :source, keyword_init: true) do
    def changed? = %i[created changed removed].include?(status)
  end

  belongs_to :owner, polymorphic: true, optional: true

  validates :kind, inclusion: { in: KINDS.keys }
  validates :body, :sha256, presence: true

  # Set by an owner that writes its own sources and handles the change itself.
  attr_accessor :skip_owner_hook

  after_save :capture_owner_hook, if: :saved_change_to_sha256?
  after_destroy :capture_owner_hook
  after_commit :notify_owner

  # Everything but the body, for code that only needs sha256 / fetched_at.
  scope :without_body, -> { select(column_names - ['body']) }
  scope :owned_by, ->(owner) { where(owner_type: owner.class.polymorphic_name, owner_id: owner.id) }

  class << self
    def digest(body) = Digest::SHA256.hexdigest(body)

    # The stored form of value for kind, or nil when there is nothing to store.
    def serialize(kind, value)
      return if value.blank?

      case format_of(kind)
      when :json then JSON.generate(canonical(value))
      else value.to_s
      end
    end

    def deserialize(kind, body)
      return if body.nil?

      format_of(kind) == :json ? JSON.parse(body) : body
    end

    # The row for owner (nil for a shared row), kind and key, or nil.
    def fetch(owner, kind, key: '')
      scope_for(owner).find_by(kind: kind.to_s, key: key)
    end

    # The stored value (parsed for JSON kinds), or nil.
    def read(owner, kind, key: '')
      fetch(owner, kind, key: key)&.value
    end

    # Stores value as the current body. Writes only when the sha256 changes; an unchanged
    # body only moves fetched_at forward (it was confirmed then), without the owner hook.
    # fetched_at: nil leaves the row's fetch time as it is (an edit, not a fetch; nil for a
    # new row). A blank value removes the row. → PutResult
    def put(owner, kind, value, key: '', fetched_at: Time.current, skip_owner_hook: false)
      put_body(owner, kind, serialize(kind, value), key: key, fetched_at: fetched_at, skip_owner_hook: skip_owner_hook)
    end

    # put with an already serialized body (nil to remove).
    def put_body(owner, kind, body, key: '', fetched_at: Time.current, skip_owner_hook: false)
      kind = kind.to_s
      format_of(kind)
      fetched_at = type_for_attribute('fetched_at').cast(fetched_at) # a String from a stored preview, too
      options = { key: key, fetched_at: fetched_at, skip_owner_hook: skip_owner_hook }
      write_body(owner, kind, body, **options)
    rescue ActiveRecord::RecordNotUnique
      # Another writer created the row between the lookup and the insert: once more, which
      # now finds it.
      write_body(owner, kind, body, **options)
    end

    def format_of(kind)
      KINDS.fetch(kind.to_s) { raise ArgumentError, "unknown source kind #{kind.inspect}" }
    end

    # value with every Hash's keys sorted (as strings), recursively.
    def canonical(value)
      case value
      when Hash then value.sort_by { |k, _| k.to_s }.to_h { |k, v| [k.to_s, canonical(v)] }
      when Array then value.map { |v| canonical(v) }
      else value
      end
    end

    private

    def write_body(owner, kind, body, key:, fetched_at:, skip_owner_hook:)
      source = fetch(owner, kind, key: key)
      return remove(source, skip_owner_hook) if body.nil?

      sha = digest(body)
      if source&.sha256 == sha
        # updated_at too: the row was confirmed now (SourceSync treats a row updated after the
        # copy as newer than the old columns).
        if fetched_at && (source.fetched_at.nil? || fetched_at > source.fetched_at)
          source.update_columns(fetched_at: fetched_at, updated_at: Time.current)
        end
        return PutResult.new(status: :unchanged, source: source)
      end

      status = source ? :changed : :created
      source ||= new(owner_type: owner&.class&.polymorphic_name, owner_id: owner&.id, kind: kind, key: key)
      source.skip_owner_hook = skip_owner_hook
      source.assign_attributes(body: body, sha256: sha)
      source.fetched_at = fetched_at if fetched_at
      # A savepoint, so a lost race on the unique index leaves an outer transaction usable.
      transaction(requires_new: true) { source.save! }
      PutResult.new(status: status, source: source)
    end

    def scope_for(owner)
      owner ? owned_by(owner) : where(owner_type: nil, owner_id: nil)
    end

    def remove(source, skip_owner_hook)
      return PutResult.new(status: :absent) if source.nil?

      source.skip_owner_hook = skip_owner_hook
      source.destroy!
      PutResult.new(status: :removed, source: source)
    end
  end

  def value
    self.class.deserialize(kind, body)
  end

  private

  # Decided when the row is written (not at commit): an owner's thread-local switches,
  # like Character.without_skill_build, are only set around the write.
  def capture_owner_hook
    return if skip_owner_hook || owner_type.nil?

    owner_class = owner_type.safe_constantize
    @owner_hook = owner_class if owner_class.respond_to?(:source_change_hook?) && owner_class.source_change_hook?(kind)
  end

  def notify_owner
    hook = @owner_hook
    @owner_hook = nil
    hook&.source_changed(owner_id, kind)
  end
end
