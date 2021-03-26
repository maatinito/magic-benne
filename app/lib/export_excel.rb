# frozen_string_literal: true

# service to download dossier report and save them in common format

require 'tempfile'
require 'open-uri'
require 'roo'
require 'fileutils'

class ExportExcel < DossierTask
  include Utils

  def version
    1
  end

  def required_fields
    super + %i[champ_etat]
  end

  def authorized_fields
    super + %i[empty_lines prefixe_fichier]
  end

  def run
    report = param_value(:champ_etat)
    return if report.nil?

    export_report(report)
  end

  private

  def export_report(report)
    file = report.file
    if file.present?
      filename = file.filename
      url = file.url
      extension = File.extname(filename)
      download_report(extension, url)
    else
      Rails.logger.warn("Pas d'état nominatif attaché au dossier #{dossier.number}")
    end
  end

  def download_report(extension, url)
    download(url, extension) do |file|
      case extension
      when '.xls', '.xlsx', '.csv'
        save_report(file)
      else
        add_message(Message::ERROR,
                    "Mauvaise extension de fichier #{extension} pour l'état du dossier #{dossier.number}")
      end
    end
  end

  def save_report(file)
    xlsx = Roo::Spreadsheet.open(file)
    regexp = sheet_regexp
    xlsx.sheets.filter { |name| name =~ regexp }.each do |name|
      save_sheet(name, xlsx.sheet(name))
    end
  end

  def save_sheet(sheet_name, sheet)
    employees = employees(sheet)
    if employees.present?
      save_employees(sheet_name, employees)
    else
      add_message(Message::ERROR, "L'onglet #{sheet_name} ne contient aucun employe")
    end
  rescue Roo::HeaderRowNotFoundError => e
    columns = e.message.gsub(%r{[/\[\]]}, '')
    add_message(Message::ERROR, "Les colonnes suivantes manquent dans le fichier Excel: #{columns}")
  end

  def save_employees(sheet_name, employees)
    Rails.logger.info("Saving #{employees.size} lines for #{sheet_name}")
    headers = employees.flat_map(&:keys).reduce(Set[], :add).to_a
    path = output_path(sheet_name)
    CSV.open(path, 'wb',
             headers: headers,
             write_headers: true,
             col_sep: ';') do |csv|
      empty_lines = params[:empty_lines]
      empty_lines.to_i.times { csv << [] } if empty_lines.present?
      employees.each do |line|
        output_line = headers.map do |column|
          value = line[column]
          case value
          when Date
            value.strftime('%d/%m/%Y')
          when Float
            value.to_s.tr('.', ',')
          else
            value
          end
        end
        csv << output_line
      end
    end
  end

  def employees(sheet)
    rows = sheet.parse(title_regexps)
    (key,) = rows&.first&.first
    rows.reject { |line| line[key].blank? }.map do |line|
      line.each do |key, value|
        line[key] = value.strip if value.is_a?(String)
        line[key] = normalize_date(value) if key.to_s.match?(/date/i)
      end
      normalize_line(line)
    end
  end

  def normalize_date(date)
    case date
    when Integer, Float
      Date.new(1899, 12, 30) + date.days
    when String
      parse(date)
    else
      date
    end
  end

  def parse(date)
    date.gsub!(%r{[-:./]}, '-')
    if match = date.match(/(\d+)-(\d+)-(\d+)/)
      day, month, year = match.captures.map(&:to_i)
      year += 2000 if year < 100
      year -= 100 if year > Date.today.year
      date = Date.new(year, month, day)
    else
      add_message(Message::ERROR, "Impossible de lire la date #{date}")
      date = Date.new(1900, 1, 1)
    end
    date
  end

  def download(url, extension)
    Tempfile.create(['res', extension]) do |f|
      f.binmode
      f.write URI.open(url).read
      f.rewind
      yield f
    end
  end

  def title_regexps
    @title_regexps ||= title_labels.map { |name| [symbolize(name), Regexp.new(name, Regexp::IGNORECASE)] }.to_h
  end

  def title_labels
    throw 'Must be defined by sub class'
  end

  def output_path(_sheet_name)
    throw 'Must be defined by sub class'
  end

  def sheet_regexp
    throw 'Must be defined by subclass'
  end

  def normalize_line(line)
    # line[:aide] = line[:aide].round if line[:aide].is_a?(Float)
    # line[:aide_maximale] = 0
    line
  end
end
