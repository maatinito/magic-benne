# frozen_string_literal: true

require 'set'

class ExportDossiers < DossierTask

  def initialize(job, params)
    super
    @calculs = create_tasks
  end

  def required_fields
    %i[champs]
  end

  def authorized_fields
    %i[calculs]
  end

  def run
    fields = params[:champs]
    line = get_fields(fields)
    add_dynamic_columns(line)
    @dossiers << line
  end

  def before_run
    @dossiers = []
    @dynamic_titles = Set.new
    @calculs.each(&:before_run)
  end

  def after_run
    @calculs.each(&:after_run)
    # pp @dossiers
    return if params[:champs].blank? || @dossiers.blank?

    titles = ['ID'] + params[:champs]
    output_path = "#{output_dir}/#{Time.zone.now.strftime('dossiers %Y-%m-%d-%Hh%M')}.csv"
    CSV.open(output_path, 'wb', headers: titles, write_headers: true, col_sep: ';') do |csv|
      @dossiers.each { |line| csv << line }
    end
  end

  def version
    1.0
  end

  private

  def get_fields(fields)
    line = [dossier.number] + fields.map do |field|
      field_values(field).map do |champ|
        case champ.__typename
        when 'TextChamp', 'IntegerNumberChamp'
          champ.value || ''
        else
          puts champ._typename
        end
      end.compact.join('|')
    end
  end

  def add_dynamic_columns(line)
    dynamic_cells = compute_cells
    @dynamic_titles.merge dynamic_cells.keys
    @dynamic_titles.each { |column| line << (dynamic_cells[column] || '') }
  end

  def compute_cells
    @calculs.map { |task| task.process_dossier(@dossier) }.reduce(&:merge)
  end

  def create_tasks()
    taches = params[:calculs]
    return [] if taches.nil?

    taches.flatten.map do |task|
      case task
      when String
        Object.const_get(task.camelize).new(job, {})
      when Hash
        task.map { |name, params| Object.const_get(name.camelize).new(@job, params || {}) }
      end
    end.flatten
  end
end
