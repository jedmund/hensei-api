object false

node :conflicts do
  partial('grid_characters/base', :object => @conflict_characters)
end

node :incoming do
  partial('characters/base', :object => @incoming_character)
end

node :position do
  @incoming_position
end
 