# frozen_string_literal: true

require 'rails_helper'
require 'fileutils'
require 'testftpd'

describe FileTransfer do
  let(:demarche_id) { 1008 }
  let(:job) { { demarche: demarche_id, name: 'name' } }
  let(:server) { '127.0.0.1' }
  let(:login) { 'username' }
  let(:password) { 'password' }
  let(:tasks) { {} }
  let(:root) { Rails.root / 'tmp/file_transfer' }
  let(:ftp_root) { root / 'remote' }
  let(:remote_dir) { ftp_root / 'input' }
  let(:local_dir) { root / 'local' }
  let(:port) { 2121 }
  let(:ftp_server) { TestFtpd::Server.new(port: port, root_dir: ftp_root.to_s) }

  subject { FileTransfer.new(job, { serveur: server, port: port, identifiant: login, mot_de_passe: password, taches: tasks }) }

  before do
    Demarche.new(id: demarche_id).save
    puts remote_dir
    puts local_dir
    FileUtils.mkdir_p remote_dir.to_s
    File.write(remote_dir / 'remote1.csv', 'CSV content')
    File.write(remote_dir / 'remote2.csv', 'CSV content')
    File.write(remote_dir / 'exclude_remote.csv', 'CSV content')
    FileUtils.mkdir_p local_dir
    File.write(local_dir / 'local1.csv', 'CSV content')
    File.write(local_dir / 'exclude_local.csv', 'CSV content')
    ftp_server.start unless ftp_server.running?
    subject.before_run
    subject.run
    subject.after_run
  end

  after do
    ftp_server.shutdown
    FileUtils.rm_rf root
  end

  context 'files to download' do
    let(:tasks) { [{ 'telecharger' => 'input/remote*.csv', 'vers' => local_dir }] }
    it 'must be transfered' do
      puts local_dir / 'remote1.csv'
      expect(File).to exist(local_dir / 'remote1.csv')
      expect(File).to exist(local_dir / 'remote2.csv')
      expect(File).not_to exist(local_dir / 'exclude_remote.csv')
      expect(File).to exist(remote_dir / 'remote1.csv')
    end
  end

  context 'files to move from remote' do
    let(:tasks) { [{ 'telecharger' => 'input/remote*.csv', 'vers' => local_dir, 'deplacer' => 'Oui' }] }
    it 'must be transfered and deleted from remote' do
      puts local_dir / 'remote1.csv'
      expect(File).to exist(local_dir / 'remote1.csv')
      expect(File).to exist(local_dir / 'remote2.csv')
      expect(File).not_to exist(local_dir / 'exclude_remote.csv')
      expect(File).not_to exist(remote_dir / 'remote1.csv')
    end
  end

  context 'files to upload' do
    let(:tasks) { [{ 'televerser' => local_dir / 'local*.csv', 'vers' => 'input', 'deplacer' => 'Non' }] }
    it 'must be transfered' do
      expect(File).to exist(remote_dir / 'local1.csv')
      expect(File).to exist(local_dir / 'local1.csv')
      expect(File).not_to exist(remote_dir / 'exclude_local.csv')
    end
  end

  context 'files to move to remote' do
    let(:tasks) { [{ 'televerser' => local_dir / 'local*.csv', 'vers' => 'input', 'deplacer' => 'Oui' }] }
    it 'must be transfered' do
      expect(File).to exist(remote_dir / 'local1.csv')
      expect(File).not_to exist(local_dir / 'local1.csv')
      expect(File).not_to exist(remote_dir / 'exclude_local.csv')
    end
  end

  context 'files to delete' do
    let(:tasks) { [{ 'effacer' => 'input/remote*.csv' }] }
    it 'must be deleted' do
      expect(File).not_to exist(remote_dir / 'remote1.csv')
      expect(File).not_to exist(remote_dir / 'remote2.csv')
      expect(File).to exist(remote_dir / 'exclude_remote.csv')
    end
  end
end
