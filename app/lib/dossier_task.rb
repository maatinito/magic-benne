# frozen_string_literal: true

require 'set'

class DossierTask < Task
  attr_reader :dossier, :exception
  attr_accessor :task_execution

  def process_dossier(dossier)
    @dossier = dossier
    @messages = []

    if dossier_has_right_state
      run
    else
      Rails.logger.info("Dossier ignoré par la tache (#{dossier.state})")
    end
  end

  def authorized_fields
    super + %i[etat_du_dossier]
  end

  def dossier_has_right_state
    @states ||= [*@params[:etats_du_dossier]].flat_map { |s| s.split(',') }.to_set
    @states.empty? || @states.include?(@dossier.state)
  end

  def run
    raise "Should be implemented by class #{self}"
  end

  def before_run; end

  def after_run; end

  def version
    @params_version ||= @params.values.reduce(Digest::SHA1.new) { |d, s| d << s.to_s }.hexdigest.to_i(16) & 0x7fffffff
    1 + @params_version
  end

  def add_message(level, message)
    @messages << Message.new(level: level, message: message)
    Rails.logger.info("Dossier: #{@dossier_nb}: #{message}")
  end

  def dedupe(filename)
    overwritten = File.exist?(filename)
    yield
    Checksum.dedupe(@task_execution, filename, overwritten: overwritten)
  end

  private

  def download_with_cache(url, filename)
    f = fetch_file(filename, url)
    if block_given?
      begin
        yield(f)
      ensure
        f.close
      end
    else
      f
    end
  end

  def fetch_file(filename, url)
    filepath = cache_file_name(filename)
    if File.exist? filepath
      f = File.open(filepath, 'rb')
    else
      f = File.open(filepath, 'wb')
      IO.copy_stream(URI.parse(url).open, f)
      f.rewind
    end
    f
  end

  def cache_file_name(filename)
    date = DateTime.iso8601(dossier.date_derniere_modification).strftime('%Y-%m-%d_%H-%M-%S')
    dir = "storage/md/#{dossier.number}"
    FileUtils.mkpath(dir)
    extension = File.extname(filename)
    "#{dir}/#{File.basename(filename, extension)}_#{date}#{extension}"
  end

  def download(url, extension)
    Tempfile.create(['res', extension]) do |f|
      f.binmode
      IO.copy_stream(URI.parse(url).open, f)
      f.rewind
      yield f
    end
  end

  def field_values(field, log_empty: true)
    return nil if @dossier.nil? || field.blank?

    objects = [*@dossier]
    field.split(/\./).each do |name|
      objects = objects.flat_map { |object| object.champs.select { |champ| champ.label == name } }
      Rails.logger.warn("Sur le dossier #{@dossier.number}, le champ #{field} est vide.") if log_empty && objects.blank?
    end
    objects
  end

  def annotation_values(name, log_empty: true)
    return nil if @dossier.nil? || name.blank?

    objects = @dossier.annotations.select { |champ| champ.label == name }
    if log_empty && objects.blank?
      Rails.logger.warn("Sur le dossier #{@dossier.number}, l'annotation #{name} est vide.")
    end
    objects
  end

  def field_value(field_name)
    field_values(field_name)&.first
  end

  def param_values(param_name)
    field_values(@params[param_name])
  end

  def param_value(param_name)
    param_values(param_name)&.first
  end

  def set_variable(variable, value)
    attribute = Attribute.find_or_create_by(dossier: @dossier_nb, task: self.class.name.underscore, variable: variable)
    attribute.value = value
    attribute.save
  end

  def get_variable(variable)
    Attribute.find_by(dossier: @dossier_nb, task: self.class.name.underscore, variable: variable)&.value
  end
end
