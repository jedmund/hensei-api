# frozen_string_literal: true

# Gives umikin, reverie and jedmund the avatars drawn for them. Their earlier
# pictures aren't recorded, so going down leaves the avatars in place.
class SetExclusiveAvatars < ActiveRecord::Migration[8.1]
  def up
    User::EXCLUSIVE_PICTURES.each do |picture, user_id|
      User.where(id: user_id).update_all(picture: picture, updated_at: Time.current)
    end
  end

  def down; end
end
