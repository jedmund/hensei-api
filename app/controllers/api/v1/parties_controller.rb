class Api::V1::PartiesController < Api::V1::ApiController
    before_action :set_from_slug, except: ['create', 'update']
    before_action :set, only: ['update', 'destroy']

    def index
        parties = Party.all
    end

    def create
        @party = Party.new(shortcode: random_string)
        @party.extra = party_params['is_extra']
        
        if current_user
            @party.user = current_user
        end

        render :show, status: :created if @party.save!
    end

    def show
        render_not_found_response if @party.nil?
    end

    def update
        if @party.user != current_user
            render_unauthorized_response
        else
            @party.extra = party_params['is_extra']
            render :update, status: :ok if @party.save!
        end
    end

    def destroy
        render :destroyed, status: :ok if @party.destroy
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
    end

    def set
        ap params
        @party = Party.where("id = ?", params[:id]).first
    end

    def party_params
        params.require(:party).permit(:user_id, :is_extra)
    end
end