# frozen_string_literal: true

require 'set'

class ExportDossierCalculations < DossierTask
  def compute
    raise "Should be implemented by class #{self}"
  end
end
