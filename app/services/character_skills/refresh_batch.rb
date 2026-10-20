# frozen_string_literal: true

module CharacterSkills
  # A batch refresh after a balance patch (PR 5, contract C6): up to MAX_CHARACTERS
  # character rows, fetched and previewed one by one in RefreshJob, then the chosen ones
  # applied from the stored text. Lives in RefreshStore for 24 hours:
  #   "batch:<id>"                      the state rendered by GET /character_skill_refreshes/:id
  #                                     (plus the owner's user_id, which isn't rendered);
  #   "batch:<id>:sources:<character>"  each previewed character's Refresh::Sources.
  #
  # Only the job writes the state while it runs; the controller writes it when it creates the
  # batch and when it accepts an apply (status previewed → applying), so the two never overlap.
  class RefreshBatch
    MAX_CHARACTERS = 20
    STATUSES = %w[queued running previewed applying applied failed].freeze
    ITEM_STATUSES = %w[queued fetching previewed applying applied skipped failed].freeze

    attr_reader :state

    # characters: Character records, in the order the editor picked them.
    def self.create(user:, characters:, refetch_jp:)
      id = "rf_#{SecureRandom.hex(16)}"
      state = {
        id: id, user_id: user.id, status: 'queued', refetch_jp: refetch_jp,
        created_at: Time.current.iso8601, items: characters.map { |character| item_for(character) }
      }
      new(state).tap(&:save)
    end

    # The batch, or nil when it's unknown, expired, or not user's.
    def self.find_for(id, user:)
      batch = find(id)
      batch if batch && batch.user_id == user&.id
    end

    def self.find(id)
      state = id.present? && RefreshStore.read(key(id))
      state ? new(state) : nil
    end

    def self.key(id) = "batch:#{id}"

    def self.item_for(character)
      {
        character_id: character.id, granblue_id: character.granblue_id, style_swap: character.style_swap,
        name: { en: character.name_en, ja: character.name_jp },
        style_name: character.style_swap ? { en: character.style_name_en, ja: character.style_name_jp } : nil,
        status: 'queued', error: nil, refresh: nil
      }
    end

    def initialize(state)
      @state = state
    end

    def id = state[:id]
    def user_id = state[:user_id]
    def status = state[:status]
    def refetch_jp = state[:refetch_jp]
    def items = state[:items]

    def item(character_id) = items.find { |item| item[:character_id] == character_id }
    def previewed_ids = items.select { |item| item[:status] == 'previewed' }.map { |item| item[:character_id] }

    # The rendered body: everything but the owner.
    def as_json(*) = state.except(:user_id, :apply_ids)

    def status!(value)
      state[:status] = value
      save
    end

    def update_item!(character_id, **attrs)
      item(character_id).merge!(attrs)
      save
    end

    # Accepts an apply for the given previewed characters (nil: every previewed one) and
    # marks the batch applying, so a poll right after the POST no longer says previewed.
    def start_apply!(character_ids)
      state[:apply_ids] = character_ids ? previewed_ids & character_ids : previewed_ids
      state[:status] = 'applying'
      save
    end

    def apply_ids = state[:apply_ids] || []

    def save
      RefreshStore.write(self.class.key(id), state, expires_in: RefreshStore::BATCH_TTL)
    end

    def store_sources(character_id, sources)
      RefreshStore.write(sources_key(character_id), sources.to_h, expires_in: RefreshStore::BATCH_TTL)
    end

    def sources(character_id)
      attrs = RefreshStore.read(sources_key(character_id))
      attrs && Refresh::Sources.new(**attrs)
    end

    private

    def sources_key(character_id) = "#{self.class.key(id)}:sources:#{character_id}"
  end
end
