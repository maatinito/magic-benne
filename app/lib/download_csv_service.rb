# frozen_string_literal: true

# service to download dossier report and save them in common format

require 'tempfile'
require 'open-uri'
require 'roo'

class DownloadCsvService
  @config = nil
  @config_time = nil

  DEMARCHE = 737

  REPORT_FIELDS = 'Etat nominatif actualisé'

  def initialize(reset: false)
    @reset = reset
  end

  def export
    DownloadCsvService.config.filter { |_k, d| d.key? 'demarche' }.each do |_procedure_name, procedure|
      demarche_number = procedure['demarche']
      demarche = Demarche.find_or_create_by({ id: demarche_number }) do |d|
        d.queried_at = EPOCH
      end
      start_time = Time.zone.now
      since = @reset ? EPOCH : demarche.queried_at
      DossierActions.on_dossiers(demarche_number, since) do |dossier|
        process_dossier(procedure, dossier)
      end
      demarche.queried_at = start_time
      demarche.save
    end
  end

  EPOCH = Time.zone.parse('2000-01-01 00:00')

  TITLE_LABELS = [
    'Nom de famille', 'Nom marital', 'Prénom', 'Date de naissance', 'DN', 'Heures avant convention',
    'Brut mensuel moyen', 'Heures à réaliser', 'DMO', 'Jours non rémunérés',
    "Jours d'indemnités journalières", 'Taux RTT*', 'Aide', 'Cotisations', '% temps présent', '% réalisé convention',
    '% perte salaire', '% aide', 'plafond'
  ].freeze

  def self.symbolize(name)
    name.tr('%', 'P').parameterize.underscore.to_sym
  end

  COLUMNS = TITLE_LABELS.map { |name| [symbolize(name), Regexp.new(name)] }.to_h

  def field(dossier, field)
    objects = [*dossier]
    field.split(/\./).each do |name|
      objects = objects.flat_map { |object| object.champs.select { |champ| champ.label == name } }
    end
    objects
  end

  MONTH_FIELD = 'Année / Mois'

  DIESE_FIELD = 'Numéro dossier DiESE'

  def process_dossier(config, dossier)
    if dossier.state == 'en_instruction'
      etat = get_field(dossier, config, 'champ_etat', REPORT_FIELDS)
      return if etat.nil?

      month_field = get_field(dossier, config, 'champ_mois', MONTH_FIELD)
      return if month_field.nil?

      year = month_field.primary_value
      month = month_field.secondary_value

      diese_field = get_field(dossier, config, 'champ_dossier', DIESE_FIELD)
      return if diese_field.nil?

      diese_number = diese_field.string_value
      # dossier_diese = diese_field.dossier

      download_report(config, dossier, etat, diese_number, month, year)
    end
  end

  def self.config
    file_mtime = File.mtime(config_file_name)
    if @config.nil? || @config_time < file_mtime
      @config = YAML.safe_load(File.read(config_file_name), [], [], true)
      @config_time = file_mtime
    end
    @config
  end

  def self.config_file_name
    @config_file_name ||= Rails.root.join('storage', 'config.yml')
  end

  private

  def download_report(config, dossier, etat, diese_number, month, year)
    file = etat.file
    if file.present?
      filename = file.filename
      url = file.url
      extension = File.extname(filename)
      if bad_extension(extension)
        Rails.logger.warn("Mauvaise extension de fichier #{extension} pour le dossier #{dossier.number}")
        return
      end
      output_dir = config['output_dir'] || 'storage'
      basename = config['champ'] || 'Etat'
      output_path = "#{output_dir}/#{basename}-#{diese_number}-#{month}-#{year}.csv"
      check_file(output_path, extension, url)
    else
      Rails.logger.warn("Pas d'état nominatif attaché au dossier #{dossier.number}")
    end
  end

  def get_field(dossier, config, field_name, default)
    dossier_field_name = config[field_name] || default
    field = field(dossier, dossier_field_name)
    if field.blank?
      Rails.logger.warn("Champ #{dossier_field_name} n'existe pas sur le dossier #{dossier.number}." \
                          " Vous pouvez le configurer via la variable '#{field_name}'")
      return nil
    end
    field.first
  end

  def check_file(output_path, extension, url)
    download(url, extension) do |file|
      case extension
      when '.xls'
        save_report(file, output_path)
      when '.xlsx'
        save_report(file, output_path)
      when '.csv'
        save_report(file, output_path)
      end
    end
  end

  def save_sheet(output_path, sheet)
    employees = employees(sheet)
    export_employee(employees, output_path)
  rescue Roo::HeaderRowNotFoundError => e
    columns = e.message.gsub(%r{[/\[\]]}, '')
    Rails.logger.error("Colonnes manquantes dans #{output_path} : #{columns}")
  end

  def export_employee(employees, output_path)
    CSV.open(output_path, 'wb',
             headers: TITLE_LABELS,
             write_headers: true,
             col_sep: ';') do |csv|
      12.times { csv << [] }
      employees.each do |line|
        csv << TITLE_LABELS.map do |column|
          value = line[DownloadCsvService.symbolize(column)]
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
    end
  end

  def employees(sheet)
    rows = sheet.parse(COLUMNS)
    rows.reject { |line| line[:prenom].nil? || line[:prenom] =~ /Prénom/ }.map do |line|
      if line[:date_de_naissance].present?
        line[:date_de_naissance] =
          Date.new(1899, 12, 30) + line[:date_de_naissance].days
      end
      pp line
      line[:aide] = line[:aide].round if line[:aide].is_a?(Float)
      line
    end
  end

  def save_report(file, output_path)
    puts file, output_path
    Rails.logger.info("Saving report to #{output_path}")
    xlsx = Roo::Spreadsheet.open(file)
    xlsx.sheets.filter { |name| name =~ /Etat|default/ }.each do |name|
      save_sheet(output_path, xlsx.sheet(name))
    end
  end

  def download(url, extension)
    Tempfile.create(['res', extension]) do |f|
      f.binmode
      f.write URI.open(url).read
      f.rewind
      yield f
    end
  end

  def bad_extension(extension)
    extension.nil? || (!extension.end_with?('.xlsx') && !extension.end_with?('.csv') && !extension.end_with?('.xls'))
  end
end
