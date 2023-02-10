# frozen_string_literal: true

class ExecuteRake < DossierTask
  def version
    super + 1
  end

  def required_fields
    super + %i[commande]
  end

  def authorized_fields
    super + %i[parametres]
  end

  def run; end

  def after_run
    Rake::Task[@params[:commande]].execute(@params[:params])
  end
end
