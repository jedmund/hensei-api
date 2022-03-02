class Api::V1::WeaponKeysController < Api::V1::ApiController
    def all
        @raids = WeaponKeys.all()
        render :all, status: :ok
    end
end