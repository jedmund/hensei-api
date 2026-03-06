# frozen_string_literal: true

require 'rails_helper'

RSpec.describe LoggingHelper do
  let(:helper_class) do
    Class.new do
      include LoggingHelper
      attr_accessor :verbose
    end
  end

  let(:helper) { helper_class.new }

  describe '#log_step' do
    it 'prints the message' do
      expect { helper.log_step('hello') }.to output("hello\n").to_stdout
    end
  end

  describe '#log_verbose' do
    it 'prints when @verbose is true' do
      helper.verbose = true
      expect { helper.log_verbose('detail') }.to output('detail').to_stdout
    end

    it 'does not print when @verbose is false' do
      helper.verbose = false
      expect { helper.log_verbose('detail') }.not_to output.to_stdout
    end

    it 'does not print when @verbose is nil' do
      expect { helper.log_verbose('detail') }.not_to output.to_stdout
    end
  end

  describe '#log_error' do
    it 'prints the error message' do
      expect { helper.log_error('boom') }.to output("boom\n").to_stdout
    end
  end

  describe '#log_warning' do
    it 'prints with warning prefix and emoji' do
      output = capture_stdout { helper.log_warning('watch out') }
      expect(output).to include('watch out')
      expect(output.length).to be > 'watch out'.length
    end
  end

  describe '#log_divider' do
    it 'prints a line of 60 characters' do
      output = capture_stdout { helper.log_divider }
      expect(output).to include('+' * 60)
    end

    it 'uses custom character' do
      output = capture_stdout { helper.log_divider('-') }
      expect(output).to include('-' * 60)
    end
  end

  describe '#log_header' do
    it 'prints title between dividers' do
      output = capture_stdout { helper.log_header('Test Header') }
      expect(output).to include('Test Header')
      expect(output.scan('+' * 60).length).to eq(2)
    end
  end

  private

  def capture_stdout
    original = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = original
  end
end
