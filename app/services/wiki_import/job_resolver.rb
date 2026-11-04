# frozen_string_literal: true

module WikiImport
  ##
  # Resolves a wiki team's class: the job by English name, its main skill, the
  # subskills it may equip, its accessory and the MC's full auto settings.
  # Unknown names and ones the class can't take are reported, never fatal.
  class JobResolver
    Result = Data.define(:job, :skill0, :skills, :accessory, :full_auto_skills)

    # Rows 4, 5 and ex2 take at most two subskills of each kind.
    LIMITED_SKILL_ROWS = %w[4 5 ex2].freeze
    MAX_SKILLS_OF_TYPE = 2

    # @param spec [WikiImport::Payload::Job, nil]
    # @param report [WikiImport::Report]
    def initialize(spec, report)
      @spec = spec
      @report = report
      @job = @skill0 = @accessory = nil
      @skills = [nil, nil, nil]
    end

    # @return [Result]
    def resolve
      return result({}) unless @spec

      resolve_job(@spec.name) if @spec.name.present?
      @spec.skills.each_with_index { |name, index| resolve_skill(name, index + 1) }
      resolve_accessory(@spec.accessory)
      result(@job ? Importer.full_auto_skills(@spec.full_auto_off) : {})
    end

    private

    def result(full_auto_skills)
      Result.new(job: @job, skill0: @skill0, skills: @skills, accessory: @accessory, full_auto_skills:)
    end

    def resolve_job(name)
      @job = Job.includes(:base_job).where('LOWER(name_en) = ?', name.strip.downcase).order(:order).first
      return @report.warn('unknown_job', name, kind: 'job', position: 0, title: name) unless @job

      @report.matched('job', 0, name, Report.named_json(@job))
      @skill0 = JobSkill.find_by(job_id: @job.id, main: true)
    end

    # Subskills match by English name among the skills this class may equip.
    # A name no skill has is unknown; one the class can't equip here (another
    # class's skill, already equipped, or over the row's limit) isn't allowed.
    def resolve_skill(name, slot)
      return if name.blank?

      candidates = JobSkill.includes(job: :base_job).where('LOWER(name_en) = ?', name.strip.downcase).to_a
      about = { kind: 'skill', position: slot, title: name }
      return @report.warn('unknown_skill', name, **about) if candidates.empty?

      skill = @job && skill_for(candidates)
      return @report.warn('skill_not_allowed', @job&.name_en || 'no class', **about) unless skill

      @skills[slot - 1] = skill
      @report.matched('skill', slot, name, Report.named_json(skill))
    end

    def skill_for(candidates)
      taken = [@skill0, *@skills].compact
      candidates = candidates.reject { |skill| taken.include?(skill) || skill.incompatible_with?(@job) }
      skill = candidates.find { |s| s.job_id == @job.id } || candidates.first
      skill if skill && room_for_skill?(skill)
    end

    def room_for_skill?(skill)
      return true unless LIMITED_SKILL_ROWS.include?(@job.row)

      type = skill.sub ? :sub : :emp
      @skills.compact.count { |s| s.public_send(type) } < MAX_SKILLS_OF_TYPE
    end

    def resolve_accessory(name)
      return if name.blank?

      rows = JobAccessory.where('LOWER(TRIM(name_en)) = ?', name.strip.downcase).to_a
      about = { kind: 'accessory', position: 0, title: name }
      return @report.warn('unknown_accessory', name, **about) if rows.empty?

      @accessory = rows.find { |row| row.accessory_type == @job.accessory_type } if @job&.accessory && @job.accessory_type.to_i.positive?
      return @report.warn('accessory_not_allowed', @job&.name_en || 'no class', **about) unless @accessory

      @report.matched('accessory', 0, name, Report.named_json(@accessory))
    end
  end
end
