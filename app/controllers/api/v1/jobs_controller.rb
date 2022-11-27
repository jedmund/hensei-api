class Api::V1::JobsController < Api::V1::ApiController
    def all
        @jobs = Job.all()
        render :all, status: :ok
    end

    def skills
        job = Job.find(params[:id])

        @skills = JobSkill.where(job: job).or(JobSkill.where(sub: true))
        render :skills, status: :ok
    end
end
