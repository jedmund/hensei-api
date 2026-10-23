# frozen_string_literal: true

module CharacterSkills
  # One effect's buff/debuff (D36, D37): the single function the effect parser and the status
  # catalogue (a status's usual category and `mixed`) both use, so they can't disagree.
  #
  #   1. an instant effect stays special;
  #   2. the game's array for the status in this skill, when its hits agree on one;
  #   3. the curated category (the user's review; never over the game);
  #   4. the effect's own text rule (StatusVerbRules);
  #   5. the status's usual category (nil while the catalogue is still working it out).
  module EffectCategory
    Result = Struct.new(:category, :source, keyword_init: true)

    module_function

    # game: { details: [{ id:, category: }] for the skill, ids: the status's display ids (the mention's
    # exact id, the status's base id), family: a 4-digit icon family to fall back on when no id hits
    # (only for statuses the wiki list lacks) }.
    def call(game:, vote:, curated: nil, usual: nil, special: false)
      return Result.new(category: 'special', source: :special) if special

      game = game_category(game.fetch(:details), game.fetch(:ids), game[:family])
      return Result.new(category: game, source: :game) if game
      return Result.new(category: curated, source: :curated) if curated
      return Result.new(category: vote, source: :rule) if vote

      Result.new(category: usual, source: :usual)
    end

    def game_category(game_details, ids, family)
      ids = ids.compact
      hits = game_details.select { |detail| ids.include?(detail[:id]) }
      if hits.empty? && family.present?
        hits = game_details.select { |detail| Granblue::Parsers::StatusName.base_game_id(detail[:id]) == family }
      end
      categories = hits.map { |detail| detail[:category] }.uniq
      categories.first if categories.one?
    end
  end
end
