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
      @party.attributes = party_params

      if party_params["job_id"].present?
        job_skills = JobSkill.where(job_id: party_params["job_id"], main: true)
        job_skills.each_with_index do |skill, i|
          @party["skill#{i}_id"] = skill.id
        end
        ap @party
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
