# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RichTextDescriptionValidator do
  let(:model_class) do
    Class.new do
      include ActiveModel::Validations
      attr_accessor :description

      def self.name = 'DescriptionHolder'

      validates :description, rich_text_description: true
    end
  end

  def valid?(description)
    model_class.new.tap { |m| m.description = description }.valid?
  end

  def doc(*content)
    { 'type' => 'doc', 'content' => content }
  end

  def heading(level)
    { 'type' => 'heading', 'attrs' => { 'level' => level }, 'content' => [{ 'type' => 'text', 'text' => 'Hi' }] }
  end

  it 'accepts nil, plain text and non-document JSON' do
    expect(valid?(nil)).to be(true)
    expect(valid?('Just some notes')).to be(true)
    expect(valid?('[1, 2]')).to be(true)
  end

  it 'accepts headings with levels 1 through 6 or no level' do
    (1..6).each { |level| expect(valid?(doc(heading(level)).to_json)).to be(true) }
    expect(valid?(doc({ 'type' => 'heading', 'content' => [] }).to_json)).to be(true)
  end

  it 'rejects heading levels that are not integers from 1 to 6' do
    ['1 onmouseover=alert(1)', '2', 0, 7, 1.5, ['1']].each do |level|
      expect(valid?(doc(heading(level)).to_json)).to be(false), "expected level #{level.inspect} to be rejected"
    end
  end

  it 'finds bad headings nested inside other nodes and in hash values' do
    nested = doc({ 'type' => 'blockquote', 'content' => [heading('3 x=y')] })
    expect(valid?(nested.to_json)).to be(false)
    expect(valid?(nested)).to be(false)
  end

  it 'rejects documents nested too deeply' do
    node = { 'type' => 'paragraph' }
    30.times { node = { 'type' => 'blockquote', 'content' => [node] } }
    expect(valid?(doc(node).to_json)).to be(true)

    30.times { node = { 'type' => 'blockquote', 'content' => [node] } }
    expect(valid?(doc(node))).to be(false) # past MAX_DEPTH

    hidden = heading('1 x=y')
    80.times { hidden = { 'type' => 'blockquote', 'content' => [hidden] } }
    expect(valid?(doc(hidden).to_json)).to be(false) # past the JSON parser's nesting limit
  end
end
