# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Processors::JobProcessor, type: :model do
  let(:party) { create(:party) }
  # Use a job that has associated job skills.
  # In our seed/canonical data this job (by its ID) has several associated skills.
  let!(:job_record) { Job.find_by!(granblue_id: '130401') }

  # Build the raw data hash that mimics the transformed structure.
  # The master section includes the job's basic information.
  # The param section includes level data and the subskills derived from the job's associated job skills.
  let(:deck_data) do
    file_path = Rails.root.join('spec', 'fixtures', 'deck_sample2.json')
    JSON.parse(File.read(file_path))
  end

  subject { described_class.new(party, deck_data, language: 'en') }

  context 'with valid job data' do
    it 'assigns the job to the party' do
      # Before processing, the party should not have a job.
      expect(party.job).to be_nil

      # Process the job data.
      subject.process
      party.reload

      # The party's job should now be set to the job_record.
      expect(party.job).to eq(job_record)
    end

    it 'assigns the correct main skill to the party' do
      # Before processing, the party should not have a job.
      expect(party.job).to be_nil

      # Process the job data.
      subject.process
      party.reload

      main_skill = party.job.skills.where(main: true).first
      expect(party.skill0.id).to eq(main_skill.id)
    end

    it 'associates the correct job skills' do
      # Before processing, the party should not have a job.
      expect(party.job).to be_nil

      # Process the job data.
      subject.process
      party.reload

      # We assume that the processor assigns up to four subskills to party attributes,
      # for example, party.skill0, party.skill1, etc.
      # Get the expected subskills (using order and taking the first four).
      data = deck_data.with_indifferent_access
      expected_subskills = data.dig('deck', 'pc', 'set_action').pluck(:name)
      actual_subskills = [party.skill1.name_en, party.skill2.name_en, party.skill3.name_en]
      expect(actual_subskills).to eq(expected_subskills)
    end

    it 'assigns the correct accessory to the party' do
      # Process the job data.
      subject.process
      party.reload

      expect(party.accessory.granblue_id).to eq(1.to_s)
    end
  end

  context 'with invalid job data' do
    let(:invalid_data) { 'invalid data' }
    subject { described_class.new(party, invalid_data, language: 'en') }

    it 'logs an error and does not assign a job' do
      expect { subject.process }.not_to(change { party.reload.job })
    end
  end

  after(:each) do |example|
    if example.exception
      puts "\nDEBUG [JobProcessor]: #{example.full_description} failed with error: #{example.exception.message}"
    end
  end
end
