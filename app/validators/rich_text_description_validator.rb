# frozen_string_literal: true

# Validates Tiptap rich-text documents stored in description fields (a JSON
# string on parties, jsonb on grid items). Plain-text descriptions pass.
#
# Clients build HTML from some node attributes, so attributes that end up in
# markup must have the shape the editor produces. Currently: heading levels
# must be 1-6.
#
#   validates :description, rich_text_description: true
class RichTextDescriptionValidator < ActiveModel::EachValidator
  HEADING_LEVELS = (1..6)

  # Maximum JSON nesting depth (objects and arrays) of a stored document.
  #
  # Rails 8.1 encodes responses with the json gem's default limit of 100
  # levels for the whole response, and grid item notes (jsonb) are rendered as
  # nested JSON. The deepest place a note appears is a substitute's
  # description: {party: {weapons: [{substitutions: [{grid_weapon: {description:
  # ...}}]}]}}, i.e. 7 levels of envelope. 80 keeps every stored note
  # renderable with room to spare (real notes are at most ~10 levels deep).
  MAX_JSON_DEPTH = 80

  def validate_each(record, attribute, value)
    doc = parse(value)
    return if doc.nil?

    record.errors.add(attribute, 'contains invalid formatting') if doc == :too_deep || !valid_node?(doc)
  end

  private

  # Returns the document hash, nil for plain text, or :too_deep for documents
  # nested past MAX_JSON_DEPTH.
  def parse(value)
    case value
    when Hash then json_depth(value) > MAX_JSON_DEPTH ? :too_deep : value
    when String
      parsed = JSON.parse(value, max_nesting: MAX_JSON_DEPTH)
      parsed.is_a?(Hash) ? parsed : nil
    end
  rescue JSON::NestingError
    :too_deep
  rescue JSON::ParserError
    nil
  end

  # Nesting depth as the json gem counts it: every object or array is a level.
  # Stops descending once past the limit.
  def json_depth(value, depth = 0)
    return depth unless value.is_a?(Hash) || value.is_a?(Array)
    return depth + 1 if depth >= MAX_JSON_DEPTH

    children = value.is_a?(Hash) ? value.values : value
    children.map { |child| json_depth(child, depth + 1) }.max || (depth + 1)
  end

  def valid_node?(node)
    return true unless node.is_a?(Hash)
    return false if node['type'] == 'heading' && !valid_heading_level?(node.dig('attrs', 'level'))

    children = node['content']
    return true if children.nil?
    return false unless children.is_a?(Array)

    children.all? { |child| valid_node?(child) }
  end

  def valid_heading_level?(level)
    return true if level.nil? # renderers default to h1

    level.is_a?(Integer) && HEADING_LEVELS.cover?(level)
  end
end
