# frozen_string_literal: true

# service to download dossier report and save them in common format

require 'tempfile'
require 'open-uri'
require 'roo'
require 'fileutils'

class ExportPiecesJointes < DossierTask
  def version
    1
  end

  def required_fields
    super + %i[champs]
  end

  def authorized_fields
    super + %i[etat_du_dossier]
  end

  def run
    champs = params[:champs]
    if champs.blank?
      Rails.logger.warn("#{self.class.name.parameterize}: Aucun nom de pièces jointes à télécharger. Remplissez l'attribut 'champs'")
      return
    end

    index = {}
    champs.each do |champ|
      values = field_values(champ)
      values.each do |value|
        export_file(champ, index, value.file)
      end
    end
  end

  private

  def self.sanitize(index, filename)
    filename = ActiveStorage::Filename.new(filename.to_s).sanitized.tr('"%', '')
    i = index[filename]
    if i.present?
      i = (index[filename] += 1)
      filename.sub(/(\.[^.]+)?$/, "-#{i}\\1")
    else
      index[filename] = 1
      filename
    end
  end

  def export_file(champ, index, file)
    if file.present?
      filename = file.filename
      url = file.url
      # no_tahiti = dossier.demandeur.siret || ''
      dir = "#{output_dir}/#{dossier.number}"
      FileUtils.mkpath(dir)
      output_path = "#{dir}/" + self.class.sanitize(index, "#{champ}-#{filename}")
      download_file(output_path, url)
      Rails.logger.info("Dossier #{dossier.number}: piece #{output_path} sauvegardée.")
    else
      Rails.logger.warn("Pas de pièce jointe dans le champ #{champ} sur le dossier #{dossier.number}")
    end
  end

  def download_file(output_path, url)
    File.open(output_path, 'w') do |f|
      f.binmode
      f.write URI.open(url).read
    end
  end
end
