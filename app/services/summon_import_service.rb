# frozen_string_literal: true

##
# Service for importing summons from game JSON data.
# Parses the game's summon inventory data and creates CollectionSummon records.
#
# @example Import summons for a user
#   service = SummonImportService.new(user, game_data)
#   result = service.import
#   if result.success?
#     puts "Imported #{result.created.size} summons"
#   end
#
class SummonImportService
  Result = Struct.new(:success?, :created, :updated, :skipped, :errors, keyword_init: true)

  def initialize(user, game_data, options = {})
    @user = user
    @game_data = game_data
    @update_existing = options[:update_existing] || false
    @created = []
    @updated = []
    @skipped = []
    @errors = []
  end

  ##
  # Imports summons from game data.
  #
  # @return [Result] Import result with counts and errors
  def import
    items = extract_items
    return Result.new(success?: false, created: [], updated: [], skipped: [], errors: ['No summon items found in data']) if items.empty?

    ActiveRecord::Base.transaction do
      items.each_with_index do |item, index|
        import_item(item, index)
      rescue StandardError => e
        @errors << { index: index, game_id: item.dig('param', 'id'), error: e.message }
      end
    end

    Result.new(
      success?: @errors.empty?,
      created: @created,
      updated: @updated,
      skipped: @skipped,
      errors: @errors
    )
  end

  private

  def extract_items
    return @game_data if @game_data.is_a?(Array)
    return @game_data['list'] if @game_data.is_a?(Hash) && @game_data['list'].is_a?(Array)

    []
  end

  def import_item(item, _index)
    param = item['param'] || {}
    master = item['master'] || {}

    # The summon's granblue_id can be in param.image_id or master.id
    # image_id may have a suffix like "_04" for transcended summons, so strip it
    image_id = param['image_id'].to_s.split('_').first if param['image_id'].present?
    granblue_id = image_id || master['id']
    game_id = param['id']

    summon = find_summon(granblue_id)
    unless summon
      @errors << { game_id: game_id, granblue_id: granblue_id, error: 'Summon not found' }
      return
    end

    # Check for existing collection summon with same game ID
    existing = @user.collection_summons.find_by(game_id: game_id.to_s)

    if existing
      if @update_existing
        update_existing_summon(existing, item, summon)
      else
        @skipped << { game_id: game_id, reason: 'Already exists' }
      end
      return
    end

    create_collection_summon(item, summon)
  end

  def find_summon(granblue_id)
    Summon.find_by(granblue_id: granblue_id.to_s)
  end

  def create_collection_summon(item, summon)
    attrs = build_collection_summon_attrs(item, summon)

    collection_summon = @user.collection_summons.build(attrs)

    if collection_summon.save
      @created << collection_summon
    else
      @errors << {
        game_id: item.dig('param', 'id'),
        granblue_id: summon.granblue_id,
        error: collection_summon.errors.full_messages.join(', ')
      }
    end
  end

  def update_existing_summon(existing, item, summon)
    attrs = build_collection_summon_attrs(item, summon)

    if existing.update(attrs)
      @updated << existing
    else
      @errors << {
        game_id: item.dig('param', 'id'),
        granblue_id: summon.granblue_id,
        error: existing.errors.full_messages.join(', ')
      }
    end
  end

  def build_collection_summon_attrs(item, summon)
    param = item['param'] || {}

    {
      summon: summon,
      game_id: param['id'].to_s,
      uncap_level: parse_uncap_level(param['evolution']),
      transcendence_step: parse_transcendence_step(param['phase'])
    }
  end

  def parse_uncap_level(evolution)
    value = evolution.to_i
    value.clamp(0, 5)
  end

  def parse_transcendence_step(phase)
    value = phase.to_i
    value.clamp(0, 10)
  end
end
