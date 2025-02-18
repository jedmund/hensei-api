# frozen_string_literal: true

module Processors
  ##
  # JobProcessor is responsible for processing job data from the transformed deck data.
  # It finds a Job record by the master’s id and assigns it (and its job skills) to the Party.
  #
  # @example
  #   raw_data = { 'job' => { "master": { "id": '130401', ... }, ... }, 'set_action': [ ... ] }
  #   processor = Processors::JobProcessor.new(party, raw_data, language: 'en')
  #   processor.process
  class JobProcessor < BaseProcessor
    ##
    # Initializes a new JobProcessor.
    #
    # @param party [Party] the Party record.
    # @param data [Hash] the raw JSON data.
    # @param options [Hash] options hash; e.g. expects :language.
    def initialize(party, data, options = {})
      super(party, options)
      @party = party
      @data = data
      @language = options[:language] || 'en'
    end

    ##
    # Processes job data.
    #
    # Finds a Job record using a case‐insensitive search on +name_en+ or +name_jp+.
    # If found, it assigns the job to the party and (if provided) assigns subskills.
    #
    # @return [void]
    def process
      if @data.is_a?(Hash)
        @data = @data.with_indifferent_access
      else
        Rails.logger.error "[JOB] Invalid data format: expected a Hash, got #{@data.class}"
        return
      end

      unless @data.key?('deck') && @data['deck'].key?('pc') && @data['deck']['pc'].key?('job')
        Rails.logger.error '[JOB] Missing job data in deck JSON'
        return
      end

      # Extract job data
      job_data = @data.dig('deck', 'pc', 'job', 'master')
      job_skills = @data.dig('deck', 'pc', 'set_action')
      job_accessory_id = @data.dig('deck', 'pc', 'familiar_id') || @data.dig('deck', 'pc', 'shield_id')

      # Look up and set the Job and its main skill
      process_core_job(job_data)

      # Look up and set the job skills.
      if job_skills.present?
        skills = process_job_skills(job_skills)
        party.update(skill1: skills[0], skill2: skills[1], skill3: skills[2])
      end

      # Look up and set the job accessory.
      accessory = process_job_accessory(job_accessory_id)
      party.update(accessory: accessory)
    rescue StandardError => e
      Rails.logger.error "[JOB] Exception during job processing: #{e.message}"
      raise e
    end

    private

    ##
    # Updates the party with the corresponding job and its main skill.
    #
    # This method attempts to locate a Job using the provided job_data's 'id' (which represents
    # the granblue_id). If the job is found, it retrieves the job's main
    # skill (i.e. the JobSkill record where `main` is true) and updates the party with the job
    # and its main skill. If no job is found, the method returns without updating.
    #
    # @param [Hash] job_data A hash containing job information.
    #   It must include the key 'id', which holds the granblue_id for the job.
    # @return [void]
    #
    # @example
    #   job_data = { 'id' => 42 }
    #   process_core_job(job_data)
    def process_core_job(job_data)
      # Look up the Job by granblue_id (the job master id).
      job = Job.find_by(granblue_id: job_data['id'])
      return unless job

      main_skill = JobSkill.find_by(job_id: job.id, main: true)

      party.update(job: job, skill0: main_skill)
    end

    ##
    # Processes and associates job skills with a given job.
    #
    # This method first removes any existing skills from the job. It then iterates over the provided
    # array of skill names, attempting to find a matching JobSkill record by comparing the provided
    # name against both the English and Japanese name fields. Any found JobSkill records are then
    # associated with the job. Finally, the method logs the processed job skill names.
    #
    # @param job_skills [Array<String>] an array of job skill names.
    # @return [Array<JobSkill>] an array of JobSkill records that were associated with the job.
    def process_job_skills(job_skills)
      job_skills.map do |skill|
        name = skill['name']
        JobSkill.find_by(name_en: name)
      end
    end

    ##
    # Processes raw data to find the currently set job accessory
    #
    # Searches JobAccessories for the given `granblue_id`
    #
    # @param accessory_id [String] the granblue_id of the accessory
    def process_job_accessory(accessory_id)
      JobAccessory.find_by(granblue_id: accessory_id)
    end

    # Converts a value (string or boolean) to a boolean.
    def to_boolean(val)
      val.to_s.downcase == 'true'
    end
  end
end
