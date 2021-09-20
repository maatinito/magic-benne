# frozen_string_literal: true

# service to download dossier report and save them in common format

require 'tempfile'
require 'open-uri'
require 'roo'
require 'fileutils'

class ExportPiecesJointes < DossierTask
  include Utils

  def version
    super + 2
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

    @index = {}
    champs.each do |champ|
      values = field_values(champ)
      values.each do |value|
        export_file(champ, value.file)
      end
    end
  end

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

  private

  def export_file(champ, file)
    if file.present?
      filename = file.filename
      url = file.url
      download_file(champ, filename, url)
      Rails.logger.info("Piece #{output} sauvegardée.")
    end
  end

  def output_path(champ, filename)
    dir = create_target_dir(dossier)
    file = self.class.sanitize(@index, "#{champ} - #{filename}")
    "#{dir}/#{file}"
  end

  def download_file(champ, filename, url)
    output = output_path(champ, filename)
    dedupe(output) do
      download_with_cache(url, filename) do |src|
        IO.copy_stream(src, output)
      end
    end
  end
end
