# frozen_string_literal: true

require 'rails_helper'
require 'fileutils'
require 'testftpd'

describe FileTransfer do
  let(:demarche_id) { 1008 }
  let(:job) { { demarche: demarche_id, name: 'name' } }
  let(:api_cle) { 'key' }
  let(:api_secret) { 'secret' }
  let(:identifiant) { 'username' }
  let(:mot_de_passe) { 'password' }
  let(:tasks) { {} }
  let(:remote_dir) { 'input' }
  let(:local_dir) { 'app/lib' }
  let(:tp_api) { double(Transfertpro::FileSystem) }

  subject { FileTransfer.new(job, { api_cle: , api_secret:, identifiant: , mot_de_passe: , taches: tasks }) }

  before do
    Demarche.new(id: demarche_id).save
    expect(FileTransfer).to receive(:tp_api).and_return(tp_api)
    expect(tp_api).to receive(:connect).with(identifiant, mot_de_passe).and_return(true)
  end

  after do
    subject.before_run
    subject.run
    subject.after_run
  end

  context 'files to download' do
    let(:tasks) { [{ 'telecharger' => 'input/remote*.csv', 'vers' => local_dir }] }
    it 'must be transfered' do
      expect(tp_api).to receive(:download_shared_files).with('input', 'remote*.csv', local_dir, { move: false}).and_return([])
    end
  end

  context 'files to move from remote' do
    let(:tasks) { [{ 'telecharger' => 'input/remote*.csv', 'vers' => local_dir, 'deplacer' => 'Oui' }] }
    it 'must be transfered and deleted from remote' do
      expect(tp_api).to receive(:download_shared_files).with('input', 'remote*.csv', local_dir, { move: true}).and_return([])
    end
  end

  context 'files to upload' do
    let(:tasks) { [{ 'televerser' => local_dir / 'local*.csv', 'vers' => remote_dir, 'deplacer' => 'Non' }] }
    it 'must be transfered' do
      expect(tp_api).to receive(:upload_shared_files).with(local_dir, 'local*.csv', remote_dir, { move: false}).and_return([])
    end
  end

  context 'files to move to remote' do
    let(:tasks) { [{ 'televerser' => local_dir / 'local*.csv', 'vers' => remote_dir, 'deplacer' => 'Oui' }] }
    it 'must be transfered' do
      expect(tp_api).to receive(:upload_shared_files).with(local_dir, 'local*.csv', remote_dir, { move: true}).and_return([])
    end
  end

  context 'files to delete' do
    let(:tasks) { [{ 'effacer' => remote_dir + '/remote*.csv' }] }
    it 'must be deleted' do
      expect(tp_api).to receive(:delete_shared_files).with(remote_dir, 'remote*.csv').and_return([])
    end
  end
end
