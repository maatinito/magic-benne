# frozen_string_literal: true

module Compute
  class RepetitionCount < DossierTask
    def version
      super + 1
    end

    def required_fields
      super + %i[champ]
    end

    def run
      {
        @params[:champ] => param_blocks(:champ)&.count || 0
      }
    end
  end
end
