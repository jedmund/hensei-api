class Api::V1::PartiesController < Api::V1::ApiController
  before_action :set_from_slug,
                except: %w[create destroy update index favorites]
  before_action :set, only: %w[update destroy]

  def create
    @party = Party.new(shortcode: random_string)
    @party.extra = party_params["extra"]

    @party.user = current_user if current_user

    render :show, status: :created if @party.save!
  end

  def show
    render_not_found_response if @party.nil?
  end

  def update
    if @party.user != current_user
      render_unauthorized_response
    else
      @party.attributes =
        party_params.except(:skill1_id, :skill2_id, :skill3_id)

      # Determine which incoming keys contain new skills
      new_skill_keys =
        party_params.keys - %i[skill0_id skill1_id skill2_id skill3_id]

      if !new_skill_keys.empty?
        # If there are new skills, merge them with the existing skills
        existing_skills = [@party.skill1, @party.skill2, @party.skill3]
        new_skill_ids = new_skill_keys.map { |key| party_params[key] }
        positions = extract_positions_from_keys(new_skill_keys)

        new_skills =
          merge_skills_with_existing_skills(
            existing_skills,
            new_skill_ids,
            positions,
          )

        new_skill_ids = {}
        new_skills.each_with_index do |skill, index|
          new_skill_ids["skill#{index + 1}_id"] = skill.id
        end

        @party.attributes = new_skill_ids
      end

      render :update, status: :ok if @party.save!
    end
  end

  def index
    @per_page = 15

    now = DateTime.current
    start_time =
      (
        now - request.params["recency"].to_i.seconds
      ).to_datetime.beginning_of_day unless request.params["recency"].blank?

    conditions = {}
    conditions[:element] = request.params["element"] unless request.params[
      "element"
    ].blank?
    conditions[:raid] = request.params["raid"] unless request.params[
      "raid"
    ].blank?
    conditions[:created_at] = start_time..now unless request.params[
      "recency"
    ].blank?
    conditions[:weapons_count] = 5..13

    @parties =
      Party
        .where(conditions)
        .order(created_at: :desc)
        .paginate(page: request.params[:page], per_page: @per_page)
        .each do |party|
          party.favorited =
            (current_user) ? party.is_favorited(current_user) : false
        end
    @count = Party.where(conditions).count

    render :all, status: :ok
  end

  def favorites
    raise Api::V1::UnauthorizedError unless current_user

    @per_page = 15

    now = DateTime.current
    start_time =
      (
        now - params["recency"].to_i.seconds
      ).to_datetime.beginning_of_day unless request.params["recency"].blank?

    conditions = {}
    conditions[:element] = request.params["element"] unless request.params[
      "element"
    ].blank?
    conditions[:raid] = request.params["raid"] unless request.params[
      "raid"
    ].blank?
    conditions[:created_at] = start_time..now unless request.params[
      "recency"
    ].blank?
    conditions[:favorites] = { user_id: current_user.id }

    @parties =
      Party
        .joins(:favorites)
        .where(conditions)
        .order("favorites.created_at DESC")
        .paginate(page: request.params[:page], per_page: @per_page)
        .each { |party| party.favorited = party.is_favorited(current_user) }
    @count = Party.joins(:favorites).where(conditions).count

    render :all, status: :ok
  end

  def destroy
    if @party.user != current_user
      render_unauthorized_response
    else
      render :destroyed, status: :ok if @party.destroy
    end
  end

  def weapons
    render_not_found_response if @party.nil?
    render :weapons, status: :ok
  end

  def summons
    render_not_found_response if @party.nil?
    render :summons, status: :ok
  end

  def characters
    render_not_found_response if @party.nil?
    render :characters, status: :ok
  end

  private

  def merge_skills_with_existing_skills(
    existing_skills,
    new_skill_ids,
    positions
  )
    new_skills = []
    new_skill_ids.each { |id| new_skills << JobSkill.find(id) }

    progress = existing_skills
    new_skills.each do |skill, index|
      progress = place_skill_in_existing_skills(progress, skill, positions[0])
    end

    return progress
  end

  def place_skill_in_existing_skills(existing_skills, skill, position)
    old_position = existing_skills.index { |x| x.id == skill.id }

    if old_position
      # Check desired position for a skill
      displaced_skill = existing_skills[position] if existing_skills[
        position
      ].present?

      # Put skill in new position
      existing_skills[position] = skill
      existing_skills[old_position] = displaced_skill
    else
      existing_skills[position] = skill
    end

    return existing_skills
  end

  def extract_positions_from_keys(keys)
    # Subtract by 1 because we won't operate on the 0th skill, so we don't pass it
    keys.map { |key| key["skill".length].to_i - 1 }
  end

  def random_string
    numChars = 6
    o = [("a".."z"), ("A".."Z"), (0..9)].map(&:to_a).flatten
    return (0...numChars).map { o[rand(o.length)] }.join
  end

  def set_from_slug
    @party = Party.where("shortcode = ?", params[:id]).first
    @party.favorited =
      (current_user && @party) ? @party.is_favorited(current_user) : false
  end

  def set
    @party = Party.where("id = ?", params[:id]).first
  end

  def party_params
    params.require(:party).permit(
      :user_id,
      :extra,
      :name,
      :description,
      :raid_id,
      :job_id,
      :skill1_id,
      :skill2_id,
      :skill3_id,
    )
  end
end
