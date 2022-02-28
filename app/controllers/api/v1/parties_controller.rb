class Api::V1::PartiesController < Api::V1::ApiController
    before_action :set_from_slug, except: ['create', 'update', 'index', 'favorites']
    before_action :set, only: ['update', 'destroy']

    def create
        @party = Party.new(shortcode: random_string)
        @party.extra = party_params['extra']
        
        if current_user
            @party.user = current_user
        end

        render :show, status: :created if @party.save!
    end

    def show
        render_not_found_response if @party.nil?
    end

    def index
        now = DateTime.current
        start_time = (now - params['recency'].to_i.seconds).to_datetime.beginning_of_day unless request.params['recency'].blank?

        conditions = {}
        conditions[:element] = request.params['element'] unless request.params['element'].blank?
        conditions[:raid] = request.params['raid'] unless request.params['raid'].blank?
        conditions[:created_at] = start_time..now unless request.params['recency'].blank? 

        @parties = Party.where(conditions).each { |party|
            party.favorited = (current_user) ? party.is_favorited(current_user) : false
        }

        render :all, status: :ok
    end

    def favorites
        raise Api::V1::UnauthorizedError unless current_user

        @parties = current_user.favorite_parties.each { |party| 
            party.favorited = party.is_favorited(current_user)
        }

        render :all, status: :ok
    end

    def update
        if @party.user != current_user
            render_unauthorized_response
        else
            @party.attributes = party_params
            render :update, status: :ok if @party.save!
        end
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
        o = [('a'..'z'), ('A'..'Z'), (0..9)].map(&:to_a).flatten
        return (0...numChars).map { o[rand(o.length)] }.join
    end

    def set_from_slug
        @party = Party.where("shortcode = ?", params[:id]).first
        @party.favorited = (current_user) ? @party.is_favorited(current_user) : false
    end

    def set
        @party = Party.where("id = ?", params[:id]).first
    end

    def party_params
        params.require(:party).permit(:user_id, :extra, :name, :description, :raid_id)
    end
end