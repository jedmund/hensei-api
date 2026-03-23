# frozen_string_literal: true

class FixCharacterAwakeningMapping < ActiveRecord::Migration[7.1]
  def up
    # The old GBF_AWAKENING_MAP in CharacterImportService was shifted by one:
    #   arousal_form 1 → character-atk (should be character-balanced)
    #   arousal_form 2 → character-def (should be character-atk)
    #   arousal_form 3 → character-multi (should be character-def)
    #   arousal_form 4 → character-balanced (should be character-multi)
    #
    # Characters at character-balanced are ambiguous (could be the default or
    # a mis-mapped arousal_form=4), so we only fix the three non-balanced cases.

    balanced = Awakening.find_by(slug: 'character-balanced', object_type: 'Character')
    atk      = Awakening.find_by(slug: 'character-atk', object_type: 'Character')
    defense  = Awakening.find_by(slug: 'character-def', object_type: 'Character')
    multi    = Awakening.find_by(slug: 'character-multi', object_type: 'Character')

    return unless balanced && atk && defense && multi

    # Collect IDs before any updates to avoid swap collisions
    was_atk_ids   = CollectionCharacter.where(awakening_id: atk.id).pluck(:id)
    was_def_ids   = CollectionCharacter.where(awakening_id: defense.id).pluck(:id)
    was_multi_ids = CollectionCharacter.where(awakening_id: multi.id).pluck(:id)

    # character-atk → character-balanced (was arousal_form=1)
    CollectionCharacter.where(id: was_atk_ids).update_all(awakening_id: balanced.id) if was_atk_ids.any?

    # character-def → character-atk (was arousal_form=2)
    CollectionCharacter.where(id: was_def_ids).update_all(awakening_id: atk.id) if was_def_ids.any?

    # character-multi → character-def (was arousal_form=3)
    CollectionCharacter.where(id: was_multi_ids).update_all(awakening_id: defense.id) if was_multi_ids.any?

    Rails.logger.info "[DATA MIGRATION] Fixed character awakening mapping: " \
      "#{was_atk_ids.size} atk→balanced, #{was_def_ids.size} def→atk, #{was_multi_ids.size} multi→def"
  end

  def down
    # Intentionally irreversible
  end
end
