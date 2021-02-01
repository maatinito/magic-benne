# frozen_string_literal: true

require 'rails_helper'
# require 'app/lib/inspector_task'

class TestDossierTask < DossierTask
  def run
    pp @dossier
    raise 'coucou' if @params[:fail]
  end

  def required_fields
    super + %i[fail]
  end
end

RSpec.describe DossierTask do
  let(:dossier) { FactoryBot.build(:dossier) }
  let(:demarche_id) { 1 }

  subject { TestDossierTask.new(demarche_id, { fail: failed }) }

  before do
    subject.process_dossier(dossier)
  end

  context 'check succeed' do
    let(:failed) { false }

    it 'should have one ExecutionTask ok' do
      expect(subject.dossier).to equal(dossier)
      expect(subject.demarche.id).to eq(demarche_id)
      expect(subject.exception).to be_nil
      expect(subject.job_task.name).to eq(subject.class.name.underscore)
    end
  end

  context 'check failed' do
    let(:failed) { true }

    it 'should have one ExecutionTask failed' do
      expect(subject.exception).to_not be_nil
    end
  end
end
