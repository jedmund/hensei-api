# frozen_string_literal: true

require 'rails_helper'

# persist used to fall through to `false` even after a successful save, and a
# failed save left no trace outside debug mode.
RSpec.describe 'Wiki parser persistence' do
  {
    Granblue::Parsers::SummonParser => [:summon, :@summon, { promotions: [] }],
    Granblue::Parsers::WeaponParser => [:weapon, :@weapon, { promotions: [] }],
    Granblue::Parsers::CharacterParser => [:character, :@character, {}]
  }.each do |parser_class, (factory, ivar, extra)|
    describe "#{parser_class.name.demodulize}#persist" do
      let(:record) { create(factory) }
      let(:parser) { parser_class.new(granblue_id: record.granblue_id) }
      let(:info) { { dates: { release_date: Date.new(2024, 3, 1) }, links: {} }.merge(extra) }

      it 'returns true and stores the info when the save succeeds' do
        expect(parser.send(:persist, info)).to be true
        expect(record.reload.release_date).to eq(Date.new(2024, 3, 1))
      end

      it 'returns false and warns with the errors when the save fails' do
        loaded = parser.instance_variable_get(ivar)
        allow(loaded).to receive(:save) do
          loaded.errors.add(:base, 'probe failure')
          false
        end
        allow(Rails.logger).to receive(:warn)

        expect(parser.send(:persist, info)).to be false
        expect(Rails.logger).to have_received(:warn).with(/Could not save info .*probe failure/)
      end
    end
  end
end
