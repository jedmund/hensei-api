object @user

extends 'api/v1/users/base'

node(:parties) {
    partial('parties/base', object: @parties)
} unless @parties.empty?