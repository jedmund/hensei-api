object :user

attributes :id,
    :username,
    :granblue_id,
    :language,
    :private,
    :gender

node :picture do |u|
    {
        :picture => u.picture,
        :element => u.element
    }
end