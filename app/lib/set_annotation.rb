# frozen_string_literal: true

require 'set'

class SetAnnotation < DossierTask
  def version
    super + 1
  end

  def required_fields
    super + %i[champ instructeur]
  end

  def authorized_fields
    super + %i[nom_fichier valeur]
  end

  def run
    instructeur = DemarcheActions.instructeur_id(@demarche_id, @params[:instructeur])
    if params[:valeur]
      value = StringTemplate.new(@dossier).instanciate(@params[:valeur])
      SetAnnotationValue.set_value(dossier, instructeur, params[:champ], value)
    elsif @params[:nom_fichier]
      filename = StringTemplate.new(@dossier).instanciate_filename(@params[:nom_fichier])
      SetAnnotationValue.set_piece_justificative(dossier, instructeur, params[:champ], filename)
    else
      raise "SetAnnotation: au moins l'attribut nom_fichier ou valeur doivent être spécifiés"
    end
  end

  def before_run; end

  def after_run; end
end
