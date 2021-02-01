# frozen_string_literal: true

class RaiseException < DossierTask
  def run
    1 / 0
  end
end
