# frozen_string_literal: true

module IdResolvable
  extend ActiveSupport::Concern

  UUID_REGEX = /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i

  private

  def uuid_format?(id)
    id.to_s.match?(UUID_REGEX)
  end

  def find_by_any_id(model_class, id)
    return nil if id.blank?

    if uuid_format?(id)
      model_class.find_by(id: id)
    else
      model_class.find_by(granblue_id: id)
    end
  end
end