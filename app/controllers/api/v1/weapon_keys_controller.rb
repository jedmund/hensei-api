class Api::V1::WeaponKeysController < Api::V1::ApiController
    def all
        conditions = {}
        conditions[:series] = request.params['series']
        conditions[:slot] = request.params['slot']
        conditions[:group] = request.params['group'] unless request.params['group'].blank?

        @keys = WeaponKey.where(conditions)
        render :all, status: :ok
    end
end