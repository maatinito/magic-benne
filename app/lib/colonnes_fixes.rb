# frozen_string_literal: true

# service to add columns with fixed values

class ColonnesFixes < ExportDossierCalculations
  def version
    1
  end

  def required_fields
    super + %i[colonnes]
  end

  def run
    params[:colonnes].map do |key, value|
      [key, value]
    end.to_h
  end
end
