# frozen_string_literal: true

require 'rails_helper'

# Dummy class including PartyQueryingConcern so that we can test its methods in isolation.
class DummyQueryClass
  include PartyQueryingConcern

  # Define a setter and getter for current_user so that the concern can call it.
  attr_accessor :current_user

  # Provide a basic params method for testing.
  attr_writer :params

  def params
    @params ||= {}
  end
end

RSpec.describe DummyQueryClass do
  let(:dummy) { DummyQueryClass.new }

  describe '#remixed_name' do
    context 'when current_user is present' do
      let(:user) { build(:user, language: 'en') }
      before { dummy.current_user = user }
      it 'returns a remix name in English' do
        expect(dummy.remixed_name('Original Party')).to eq('Remix of Original Party')
      end

      context 'when user language is Japanese' do
        let(:user) { build(:user, language: 'ja') }
        before { dummy.current_user = user }
        it 'returns a remix name in Japanese' do
          expect(dummy.remixed_name('オリジナル')).to eq('オリジナルのリミックス')
        end
      end
    end

    context 'when current_user is nil' do
      before { dummy.current_user = nil }
      it 'returns a remix name in English by default' do
        expect(dummy.remixed_name('Original Party')).to eq('Remix of Original Party')
      end
    end
  end
end
