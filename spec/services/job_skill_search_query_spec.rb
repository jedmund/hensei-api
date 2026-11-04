# frozen_string_literal: true

require 'rails_helper'

RSpec.describe JobSkillSearchQuery do
  def call(job, locale: 'en', **params)
    described_class.call(ActionController::Parameters.new(params).permit!, locale: locale, job: job)
  end

  let(:base) { create(:job) }
  let(:job) { create(:job, base_job: base) }
  let(:sibling) { create(:job, base_job: base) }

  let!(:own) { create(:job_skill, job: job, name_en: 'Zyx own', name_jp: 'ズィクス', color: 3) }
  let!(:own_main) { create(:job_skill, :main_skill, job: job, name_en: 'Zyx main') }
  let!(:base_own) { create(:job_skill, :base_skill, job: base, name_en: 'Zyx base own') }
  let!(:sibling_base) { create(:job_skill, :base_skill, job: sibling, name_en: 'Zyx base sibling') }
  let!(:sibling_emp) { create(:job_skill, :emp_skill, job: sibling, name_en: 'Zyx emp') }
  let(:mine) { [own, own_main, base_own, sibling_base, sibling_emp] }

  it "lists the job's skills with its base job's base skills" do
    expect(call(job).to_a & mine).to contain_exactly(own, base_own, sibling_emp)
  end

  it "offers siblings' base skills when searching" do
    expect(call(job, query: 'Zyx').to_a & mine).to contain_exactly(own, sibling_base, sibling_emp)
  end

  it 'searches the language name' do
    expect(call(job, query: 'ズィクス', locale: 'ja').to_a & mine).to eq([own])
  end

  it 'filters by color, EMP and base groups' do
    expect(call(job, filters: { 'group' => '3' }).to_a & mine).to eq([own])
    expect(call(job, filters: { 'group' => 4 }).to_a & mine).to eq([sibling_emp])
    expect(call(job, filters: { 'group' => 5 }).to_a & mine).to eq([base_own])
    expect(call(job, filters: { 'group' => -1 }).to_a & mine).to contain_exactly(own, base_own, sibling_emp)
  end

  it 'lists only its own skills for a job without a base job' do
    expect(call(base).to_a & mine).to eq([base_own])
  end
end
