# frozen_string_literal: true

class FieldSource < SimpleDelegator
  def initialize(dossier, hash, block = nil)
    super(dossier)
    @hash = hash.with_indifferent_access
    @block = block
  end

  def [](key)
    @hash[key]
  end

  def champs
    [*@block&.champs, *super].compact
  end
end
