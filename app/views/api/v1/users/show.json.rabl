object false

node :user do
    partial('users/base', object: @user)
end

child :parties do
    node :count do
        @count
    end
    
    node :total_pages do
        (@count.to_f / @per_page > 1) ? (@count.to_f / @per_page).ceil() : 1  
    end
    
    node :results do
        partial('parties/base', object: @parties)
    end unless @parties.empty?
end