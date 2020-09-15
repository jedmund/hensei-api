object false

child(@user) {
    attributes :id, :email, :username
} unless @user.blank?

node(:error) {
    @error
} unless @error.blank?
