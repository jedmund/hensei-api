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
  # Node depth, not JSON depth: each node level is ~2 levels of JSON. Keeps
  # stored documents under the 100-level limit Rails' to_json enforces when
  # rendering them (jsonb notes are rendered as nested JSON).
  MAX_DEPTH = 40

  def validate_each(record, attribute, value)
    doc = parse(value)
    return if doc.nil?

    record.errors.add(attribute, 'contains invalid formatting') if doc == :too_deep || !valid_node?(doc, 0)
  end

  private

  # Returns the document hash, nil for plain text, or :too_deep for JSON nested
  # past the parser limit (browsers would still parse and render it).
  def parse(value)
    case value
    when Hash then value
    when String
      parsed = JSON.parse(value)
      parsed.is_a?(Hash) ? parsed : nil
    end
  rescue JSON::NestingError
    :too_deep
  rescue JSON::ParserError
    nil
  end

  def valid_node?(node, depth)
    return false if depth > MAX_DEPTH
    return true unless node.is_a?(Hash)
    return false if node['type'] == 'heading' && !valid_heading_level?(node.dig('attrs', 'level'))

    children = node['content']
    return true if children.nil?
    return false unless children.is_a?(Array)

    children.all? { |child| valid_node?(child, depth + 1) }
  end

  def valid_heading_level?(level)
    return true if level.nil? # renderers default to h1

    level.is_a?(Integer) && HEADING_LEVELS.cover?(level)
  end
end
