# frozen_string_literal: true

##
# The actions every grid controller (weapons, characters, summons) shares:
# moving and swapping slots, uncapping, removing, and syncing a row with its
# linked collection item, plus the lookups they run on.
#
# A controller declares its type once:
#
#   grid_item GridWeapon, blueprint: GridWeaponBlueprint, view: :full,
#                         party_param_keys: %i[weapon resolve]
#
# and keeps its own create/update and whatever only its type has. The row is
# always @grid_item, and @party is always the party the row belongs to. Where
# rows may sit and what a move does to the party is GridPlacement's job.
#
# Requires PartyAuthorizationConcern, CollectionSourceConcern,
# SubstituteGridPreloading and PartyFullLoading.
module GridItemActions
  extend ActiveSupport::Concern

  # Actions that work on one existing row, found by find_grid_item.
  ROW_ACTIONS = %i[update update_uncap_level update_position destroy sync sync_to_collection].freeze

  # Actions that edit a party, found by find_party and checked by authorize_party_edit!.
  EDIT_ACTIONS = (ROW_ACTIONS + %i[create swap]).freeze

  # How one kind of grid row behaves.
  #
  # - name: 'weapon', 'character' or 'summon'; also the request's param key
  # - view: the blueprint view rows are rendered with
  # - party_param_keys: payloads that may carry a party_id
  # - reports_reordered: the move response says whether slots were compacted
  # - reloads_moved: the move response reloads the row (weapons render it as
  #   loaded, so its substitutes keep their owned flags)
  GridItemType = Data.define(:model, :blueprint, :name, :view, :party_param_keys, :reports_reordered, :reloads_moved) do
    def param_key = name.to_sym
    def root = :"grid_#{name}"
    def collection_association = :"collection_#{name}"
  end

  included do
    class_attribute :grid_item_type, instance_writer: false
  end

  class_methods do
    def grid_item(model, blueprint:, view:, party_param_keys: nil, reports_reordered: false, reloads_moved: true)
      name = model.name.delete_prefix('Grid').underscore
      self.grid_item_type = GridItemType.new(
        model: model, blueprint: blueprint, name: name, view: view,
        party_param_keys: party_param_keys || [name.to_sym],
        reports_reordered: reports_reordered, reloads_moved: reloads_moved
      )
    end
  end

  ##
  # Updates the uncap level and transcendence step of a row.
  #
  # @return [void]
  def update_uncap_level
    uncap = grid_item_params(:uncap_level, :transcendence_step)
    @grid_item.apply_uncap(uncap_level: uncap[:uncap_level], transcendence_step: uncap[:transcendence_step])

    if @grid_item.save
      render json: grid_item_type.blueprint.render(@grid_item, view: :uncap, root: grid_item_type.root), status: :ok
    else
      render_validation_error_response(@grid_item)
    end
  end

  ##
  # Moves a row to an empty slot in its party.
  #
  # @return [void]
  def update_position
    move = GridPlacement.move(@grid_item, position_params[:position].to_i)
    return render_validation_error_response(@grid_item) unless move.saved

    @party.mark_updated!
    moved = grid_item_type.reloads_moved ? @grid_item.reload : @grid_item
    body = {
      party: Api::V1::PartyBlueprint.render_as_hash(load_full_party(@party.id), view: :full),
      grid_item_type.root => grid_item_type.blueprint.render_as_hash(moved, view: grid_item_type.view)
    }
    body[:reordered] = move.reordered if grid_item_type.reports_reordered

    render json: body, status: :ok
  rescue GridPlacement::Error => e
    render_placement_error(e)
  end

  ##
  # Swaps the slots of two rows in the same party.
  #
  # @return [void]
  def swap
    source = party_row(swap_params[:source_id])
    target = party_row(swap_params[:target_id])
    return render_not_found_response(grid_item_type.root.to_s) unless source && target

    GridPlacement.swap!(source, target)
    @party.mark_updated!

    render json: {
      party: Api::V1::PartyBlueprint.render_as_hash(load_full_party(@party.id), view: :full),
      swapped: {
        source: grid_item_type.blueprint.render_as_hash(source.reload, view: grid_item_type.view),
        target: grid_item_type.blueprint.render_as_hash(target.reload, view: grid_item_type.view)
      }
    }, status: :ok
  rescue GridPlacement::Error => e
    render_placement_error(e)
  rescue ActiveRecord::RecordInvalid => e
    render_validation_error_response(e.record)
  end

  ##
  # Removes a row from its party.
  #
  # @return [void]
  def destroy
    if @grid_item.destroy
      @party.mark_updated!
      clear_collection_source_if_empty!(@party)
      render json: grid_item_type.blueprint.render(@grid_item, view: :destroyed), status: :ok
    else
      render_unprocessable_entity_response(
        Api::V1::GranblueError.new(@grid_item.errors.full_messages.join(', '))
      )
    end
  end

  ##
  # Copies the linked collection item onto the row.
  #
  # @return [void]
  def sync
    collection_item = @grid_item.public_send(grid_item_type.collection_association)
    return render_no_collection_item if collection_item.blank?
    return unless validate_collection_access!(collection_item)

    @grid_item.sync_from_collection!(fields: sync_fields_param)
    render_grid_item(@grid_item.reload)
  end

  ##
  # Copies the row onto its linked collection item. Only the owner of the
  # collection the party draws from may do this.
  #
  # @return [void]
  def sync_to_collection
    collection_item = @grid_item.public_send(grid_item_type.collection_association)
    return render_no_collection_item if collection_item.blank?

    unless current_user.present? && @party.collection_source_user_id == current_user.id &&
           collection_item.user_id == current_user.id
      return render_unauthorized_response
    end

    @grid_item.sync_to_collection!(fields: sync_fields_param)
    render_grid_item(@grid_item.reload)
  end

  private

  ##
  # Finds the row from params[:id] or the payload's id.
  #
  # @return [void]
  def find_grid_item
    model = grid_item_type.model
    @grid_item = model.includes(*model::NESTED_BLUEPRINT_PRELOADS, :substitutions)
                      .find_by(id: params[:id] || params.dig(grid_item_type.param_key, :id))
    return render_not_found_response(grid_item_type.root.to_s) unless @grid_item

    preload_substitute_grids!([@grid_item])
  end

  ##
  # Finds the party. For an existing row it is always the row's own party; a
  # different party id in the request is treated as not found. Otherwise the
  # party comes from the request.
  #
  # @return [void]
  def find_party
    requested_party_id = requested_party_id_param
    @party = if @grid_item
               @grid_item.party if requested_party_id.blank? || requested_party_id.to_s == @grid_item.party_id.to_s
             else
               Party.find_by(id: requested_party_id)
             end
    render_not_found_response('party') unless @party
  end

  # The first party_id the request carries, checking the type's payloads first.
  def requested_party_id_param
    grid_item_type.party_param_keys.lazy.filter_map { |key| params.dig(key, :party_id) }.first || params[:party_id]
  end

  # The permitted fields of the type's payload, plus its rich-text description.
  def grid_item_params(*filters)
    raw = params.require(grid_item_type.param_key)
    permit_description(raw.permit(*filters), raw)
  end

  ##
  # Pulls the optional `fields` array (camelCase keys) from the request body
  # used by per-section sync. Returns nil when omitted so the model falls
  # back to syncing every tracked column.
  def sync_fields_param
    raw = params[:fields]
    return nil if raw.blank?

    Array(raw).map(&:to_s).compact_blank
  end

  def position_params
    params.permit(:position, :container)
  end

  def swap_params
    params.permit(:source_id, :target_id)
  end

  # A row of this type in @party, or nil; never a row from another party.
  def party_row(id)
    grid_item_type.model.find_by(id: id, party_id: @party.id)
  end

  # A placement refusal as the API's error for it.
  def render_placement_error(error)
    api_error = error.is_a?(GridPlacement::PositionOccupied) ? Api::V1::PositionOccupiedError : Api::V1::InvalidPositionError
    render_unprocessable_entity_response(api_error.new(error.message))
  end

  def render_grid_item(grid_item)
    render json: grid_item_type.blueprint.render(grid_item, root: grid_item_type.root, view: grid_item_type.view)
  end

  def render_no_collection_item
    render_unprocessable_entity_response(
      Api::V1::GranblueError.new("No collection #{grid_item_type.name} linked")
    )
  end

  ##
  # Renders a row that took over a slot, with the slot it came from.
  #
  # @param grid_item [GridWeapon, GridSummon] the row to render
  # @param conflict_position [Integer, nil] the slot it left
  # @return [String] the rendered view
  def render_replaced_view(grid_item, conflict_position = nil)
    grid_item_type.blueprint.render(grid_item, view: :full, root: grid_item_type.root,
                                               meta: { replaced: conflict_position })
  end

  ##
  # Renders the conflict view: the rows already in the party that the incoming
  # item can't sit beside.
  #
  # @param conflicts [Array] the conflicting rows
  # @param incoming [Weapon, Character] the item being added
  # @param incoming_position [Integer] the slot it was meant for
  # @return [String] the rendered conflict view
  def render_conflict_view(conflicts, incoming, incoming_position)
    name = grid_item_type.name
    Api::V1::ConflictBlueprint.render(nil,
                                      view: :"#{name}s",
                                      "conflict_#{name}s": conflicts,
                                      "incoming_#{name}": incoming,
                                      incoming_position: incoming_position)
  end

  ##
  # Applies a notes sync change from an update payload: turning the switch on
  # or off, or else spreading a new description to the rest of the group.
  # Call inside the update's transaction so the group can't drift.
  #
  # @return [void]
  def apply_notes_sync!(item_params)
    sync_flag = (ActiveModel::Type::Boolean.new.cast(item_params[:notes_synced]) if item_params.key?(:notes_synced))

    if sync_flag == true
      NotesSync.enable_sync!(@grid_item)
    elsif sync_flag == false
      NotesSync.disable_sync!(@grid_item)
    elsif item_params.key?(:description)
      NotesSync.propagate_description!(@grid_item)
    end
  end
end
