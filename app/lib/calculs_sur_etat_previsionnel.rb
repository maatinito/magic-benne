# frozen_string_literal: true

# service to download dossier report and save them in common format

require 'tempfile'
require 'open-uri'
require 'roo'
require 'fileutils'

class CalculsSurEtatPrevisionnel < ExportDossierCalculations
  def version
    super + 1
  end

  def required_fields
    %i[champ_etat]
  end

  CELLS = {
    'Nombre de salariés' => 'H4',
    'Aide brut' => 'H5',
    'Cotisations' => 'H6'
  }.freeze

  def run
    etat = param_value(:champ_etat)
    return if etat.nil?

    computed_columns_from_field(etat)
  end

  private

  def computed_columns_from_field(etat)
    file_desc = etat.file
    if file_desc.present?
      download_with_cache(file_desc.url, file_desc.filename) do |file|
        case File.extname(file_desc.filename)
        when '.xls', '.xlsx', '.csv'
          computed_columns_from_file(file)
        else
          add_message(Message::ERROR,
                      "Mauvaise extension de fichier #{extension} pour l'état du dossier #{dossier.number}")
        end
      end
    else
      add_message(Message::WARN, "Pas d'état nominatif attaché au dossier #{dossier.number}")
    end
  end

  def computed_columns_from_file(file)
    xlsx = Roo::Spreadsheet.open(file)
    cells = {}
    xlsx.sheets.filter { |name| name =~ /Mois/ }.each do |name|
      cells.merge!(computed_columns_from_sheet(xlsx.sheet(name), name))
    end
    cells
  end

  def computed_columns_from_sheet(sheet, name)
    CELLS.to_h do |key, cell|
      puts "#{name}/#{key}/#{cell}"
      [
        "#{key} #{name}",
        normalize(sheet.cell(cell[1].to_i, cell[0]))
      ]
    end
  rescue Roo::HeaderRowNotFoundError => e
    columns = e.message.gsub(%r{[/\[\]]}, '')
    add_message(Message::ERROR, "Les colonnes suivantes manquent dans le fichier Excel: #{columns}")
  end

  def normalize(value)
    case value
    when Date
      value.strftime('%d/%m/%Y')
    when Float
      value.to_s.tr('.', ',')
    else
      value
    end
  end
end
