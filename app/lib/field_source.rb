# frozen_string_literal: true

class FieldSource < SimpleDelegator
  def initialize(dossier, hash)
    super(dossier)
    @hash = hash.with_indifferent_access
  end

  def [](key)
    @hash[key]
  end
end
