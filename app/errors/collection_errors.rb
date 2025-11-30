# frozen_string_literal: true

module CollectionErrors
  # Base class for all collection-related errors
  class CollectionError < StandardError
    attr_reader :http_status, :code

    def initialize(message = nil, http_status: :unprocessable_entity, code: nil)
      super(message)
      @http_status = http_status
      @code = code || self.class.name.demodulize.underscore
    end

    def to_hash
      {
        error: {
          type: self.class.name.demodulize,
          message: message,
          code: code
        }
      }
    end
  end

  # Raised when a collection item cannot be found
  class CollectionItemNotFound < CollectionError
    def initialize(item_type = 'item', item_id = nil)
      message = item_id ? "Collection #{item_type} with ID #{item_id} not found" : "Collection #{item_type} not found"
      super(message, http_status: :not_found)
    end
  end

  # Raised when trying to add a duplicate character to collection
  class DuplicateCharacter < CollectionError
    def initialize(character_id = nil)
      message = character_id ? "Character #{character_id} already exists in your collection" : "Character already exists in your collection"
      super(message, http_status: :conflict)
    end
  end

  # Raised when trying to add a duplicate job accessory to collection
  class DuplicateJobAccessory < CollectionError
    def initialize(accessory_id = nil)
      message = accessory_id ? "Job accessory #{accessory_id} already exists in your collection" : "Job accessory already exists in your collection"
      super(message, http_status: :conflict)
    end
  end
end