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
    compute_dynamic_fields
    subfields = params[:champs]
    repetitions = param_values(:bloc)
    lines = repetitions_to_table(repetitions, subfields)

    lines.each do |line|
      save_csv(line)
    end
  end

  private

  def output_path
    field_name = ActiveStorage::Filename.new(@params[:bloc].to_s).sanitized.tr('"%', '')
    "#{output_dir}/#{@demarche_dir}-#{demarche_id}-#{field_name}-#{Time.zone.now.strftime('%Y-%m-%d-%Hh%M')}.csv"
  end

  def repetitions_to_table(repetitions, subfields)
    repetitions.flat_map do |repetition|
      repetition_to_table(repetition, subfields) if repetition.__typename == 'RepetitionChamp' && repetition.champs.present?
    end.compact
  end

  def get_block_fields(block, columns)
    [dossier.number] + columns.map { |column| get_block_field(block, column) }
  end

  def get_block_field(block, column)
    field, default = definition(column)
    return default unless field

    names = field.split(/\./)
    return nil if names.blank?

    champs = select_champ(block, names.shift)
    look_at_document = champs.blank?
    return get_field(column) if look_at_document

    methods_to_call_on_champs = names.present?
    return champs_to_values(champs) unless methods_to_call_on_champs

    objects = champs
    names.each do |name|
      objects = objects.filter_map { |object| object.send(name) if object.respond_to?(name) }
      objects.map! { |v| v.is_a?(String) ? Date.iso8601(v) : v } if name.match?(/date/i)
    end
    objects.present? ? objects : default
  end

  def repetition_to_table(repetition, subfields)
    blocks_from(repetition).map do |block|
      get_block_fields(block, subfields)
    end
  end

  def blocks_from(repetition_champ)
    repetition_champ.champs.each_with_object([[]]) do |champ, result|
      block = result.last
      result << (block = []) if block.first&.label == champ.label # next line/hash
      block << champ
    end
  end
end
