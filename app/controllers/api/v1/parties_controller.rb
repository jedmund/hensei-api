class Api::V1::PartiesController < Api::V1::ApiController
    before_action :set, except: ['create']

    def index
        parties = Party.all
    end

    def create
        @party = Party.new(shortcode: random_string, user_id: party_params[:user_id])
        render :show, status: :created if @party.save!
    end

    def show
        render_not_found_response if @party.nil?
    end

    def update
    end

    def destroy
    end

    private

    def random_string
        numChars = 6
        o = [('a'..'z'), ('A'..'Z'), (0..9)].map(&:to_a).flatten
        return (0...numChars).map { o[rand(o.length)] }.join
    end

    def set
        @party = Party.where("shortcode = ?", params[:id]).first
    end

    def party_params
        params.require(:party).permit(:user_id)
    end
end