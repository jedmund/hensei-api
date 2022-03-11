node :count do
    @count
end

node :total_pages do
    (@count.to_f / 10 > 1) ? (@count.to_f / 10).ceil() : 1  
end

node(:results) {
    partial('characters/base', object: @characters)
} unless @characters.empty?
