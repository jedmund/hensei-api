node :count do
    @count
end

node :total_pages do
    (@count.to_f / @per_page > 1) ? (@count.to_f / @per_page).ceil() : 1  
end

node(:results) {
    partial('parties/base', object: @parties)
} unless @parties.empty?
