# frozen_string_literal: true

require 'rails_helper'

VCR.use_cassette('ds') do
  DEMARCHE = 828
  DemarcheActions.get_instructeur_id(DEMARCHE, 'clautier@idt.pf')

  describe 'DemarcheService' do
    subject { DemarcheService.new(reset: true, config_file: file_fixture(config)) }
    before do
      subject.process
    end

    context 'when no task to execute', vcr: { cassette_name: 'all_dossier' } do
      let(:config) { 'empty.yml' }
      it 'succeeds' do
        expect(Demarche.find(DEMARCHE)).to_not be_nil
        expect(TaskExecution.count).to eq(0)
        expect(JobTask.count).to eq(0)
      end
    end

    context 'when one task to execute', vcr: { cassette_name: 'all_dossiers' } do
      let(:config) { 'one_task.yml' }
      it 'succeeds' do
        expect(Demarche.find(DEMARCHE)).to_not be_nil
        expect(TaskExecution.count).to eq(1)
        expect(JobTask.count).to eq(1)
      end
    end

    context 'when one task raise an exception', vcr: { cassette_name: 'all_dossiers' } do
      let(:config) { 'raise_exception.yml' }
      it 'must handle exception' do
        expect(Demarche.find(DEMARCHE)).to_not be_nil
        expect(JobTask.all.map(&:name)).to eq(%w[does_nothing raise_exception])
        expect(TaskExecution.all.map(&:failed)).to eq([false, true])
      end
    end
  end
end
