# frozen_string_literal: true

# service to download dossier report and save them in common format

require 'tempfile'
require 'open-uri'
require 'roo'
require 'fileutils'

class ExportExcel < DossierTask
  include Utils

  def version
    super + 3
  end

  def required_fields
    super + %i[champ]
  end

  def authorized_fields
    super + %i[empty_lines prefixe_fichier bloc colonnes_champs champ_etat]
  end

  def run
    if @params[:bloc]
      for_each_repetition(:bloc) do
        export
      end
    else
      export
    end
  end

  private

  def export
    param = @params.key?(:champ) ? :champ : :champ_etat
    reports = object_values(@block || @dossier, @params[param])
    reports.each { |report| export_report(report) }
  end

  def normalize_int(symbol, line)
    line[symbol] = to_i(line[symbol])
  end

  def to_i(value)
    value = value.to_i if value.is_a?(String)
    value = value.round if value.is_a?(Float)
    value
  end

  def export_report(report)
    file = report.file
    if file.present?
      filename = file.filename
      url = file.url
      download_report(filename, url)
    else
      Rails.logger.warn("Pas d'état nominatif attaché au dossier #{dossier.number}")
    end
  end

  def download_report(filename, url)
    extension = File.extname(filename).downcase
    case extension
    when '.xls', '.xlsx', '.csv'
      download_with_cache(url, filename) do |file|
        save_report(file)
      end
    else
      add_message(Message::ERROR,
                  "Le fichier #{filename} dans le dossier  #{dossier.number} n'est pas un fichier Excel: #{extension}")
    end
  end

  def save_report(file)
    xlsx = Roo::Spreadsheet.open(file)
    regexp = sheet_regexp
    if regexp.present?
      xlsx.sheets.grep(regexp).each do |name|
        save_sheet(name, xlsx.sheet(name))
      end
    else
      # save first sheet by default
      save_sheet(name, xlsx.sheet(0))
    end
  rescue Zip::Error => e
    add_message(Message::ERROR, "Impossible d'ouvrir le fichier Excel. (#{e.message})")
  end

  def save_sheet(sheet_name, sheet)
    rows = rows(sheet)
    save_rows(sheet_name, rows)
  rescue Roo::HeaderRowNotFoundError => e
    columns = e.message.gsub(%r{[/\[\]]}, '')
    add_message(Message::ERROR, "Les colonnes suivantes manquent dans le fichier Excel: #{columns}")
  end

  def save_rows(sheet_name, rows)
    return unless sheet_ok?(sheet_name, rows)

    Rails.logger.info("Saving #{rows.size} lines for #{sheet_name}")
    headers = rows.flat_map(&:keys).reduce(Set[], :add).to_a
    path = output_path(sheet_name)
    dedupe(path) do
      CSV.open(path, 'wb',
               headers:,
               write_headers: true,
               col_sep: ';') do |csv|
        empty_lines = params[:empty_lines]
        empty_lines.to_i.times { csv << [] } if empty_lines.present?
        rows.each do |line|
          output_line = headers.map do |column|
            value = line[column]
            case value
            when Date
              value.strftime('%d/%m/%Y')
            when Float
              value.to_s.tr('.', ',')
            when String
              value.strip.gsub(/\s+/, ' ').gsub(';', ',')
            else
              value
            end
          end
          csv << output_line
        end
      end
    end
  end

  def sheet_ok?(sheet_name, rows)
    unless (ok = rows.present?)
      add_message(Message::ERROR, "L'onglet #{sheet_name} ne contient aucun employe")
    end
    ok
  end

  def rows(sheet)
    @title_regexps ||= title_regexps
    rows = sheet.parse(@title_regexps)
    (first_column_title, _value) = rows&.first&.first
    rows.reject { |line| line[first_column_title].blank? }.map do |line|
      line.each do |key, value|
        line[key] = value.strip if value.is_a?(String)
        line[key] = normalize_date(value) if key.to_s.match?(/date/i)
      end
      normalize_line(line)
      field_columns.merge!(line)
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
    if (match = date.match(/(\d+)-(\d+)-(\d+)/))
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

  def title_regexps
    title_labels.to_h do |name|
      [symbolize(name),
       Regexp.new(name, Regexp::IGNORECASE)]
    end
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
    line
  end

  def field_columns
    @columns ||= params[:colonnes_champs]
    return {} unless @columns.present?

    @columns.each_with_object({}) do |column_definition, h|
      field, default, column = definition(column_definition)
      values = get_field_values(field, default)
      #---- normalize dates & stores only one global string value for each cell
      values.map! do |v|
        case v
        when DateTime
          v.iso8601
        when Date
          v.strftime('%d/%m/%Y')
        else
          v
        end
      end
      h[column] = values.join('|').strip.tr(';', '/')
    end
  end

  def definition(definition)
    if definition.is_a?(Hash)
      par_defaut = definition['par_defaut'] || ''
      field = definition['champ']
      column = definition['colonne']
    else
      column = definition.to_s
      field = definition.to_s
      par_defaut = "Unknown field #{field}"
    end
    [field, par_defaut, column]
  end
end
