# frozen_string_literal: true

require 'set'

class ExportBlocs < ExportDossiers
  def version
    super + 1
  end

  def required_fields
    super + %i[bloc]
  end

  def run
    subfields = params[:champs]
    repetitions = param_values(:bloc)
    lines = repetitions_to_table(repetitions, subfields)
    lines.each do |line|
      add_dynamic_columns(line)
      @dossiers << line
    end
  end

  private

  def output_path
    field_name = ActiveStorage::Filename.new(@params[:bloc].to_s).sanitized.tr('"%', '')
    "#{output_dir}/#{@demarche_dir}-#{demarche_id}-#{field_name}-#{Time.zone.now.strftime('%Y-%m-%d-%Hh%M')}.csv"
  end

  private

  def repetitions_to_table(repetitions, subfields)
    repetitions.flat_map do |repetition|
      repetition_to_table(repetition, subfields) if repetition.__typename == 'RepetitionChamp'
    end
  end

  def repetition_to_table(repetition, subfields)
    repetition_hashes(repetition).map do |hash|
      [@dossier.number] + subfields.map do |field|
        hash[field] || get_field(field)
      end
    end
  end

  def repetition_hashes(repetition_champ)
    repetition_champ.champs.reduce([{}]) do |result, champ|
      hash_line = result.last
      result << (hash_line = {}) if hash_line.key?(champ.label) # next line/hash
      hash_line[champ.label] = champ_value(champ)
      result
    end
  end
end
