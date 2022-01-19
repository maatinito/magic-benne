# frozen_string_literal: true

# service to add columns with fixed values

class ColonnesFixes < ExportDossierCalculations
  def version
    super + 1
  end

  def required_fields
    super + %i[colonnes]
  end

  def run
    params[:colonnes].to_h do |key, value|
      [key, value]
    end
  end
end
