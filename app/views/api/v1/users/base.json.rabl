object :user

attributes :id,
    :username,
    :granblue_id,
    :language,
    :private

node :picture do |u|
    {
        :picture => u.picture,
        :element => u.element
    }
end