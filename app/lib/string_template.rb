# frozen_string_literal: true

class StringTemplate
  include DossierHelper

  def initialize(source)
    @source = source
  end

  def instanciate(template)
    template.gsub(/{([^{}%]+)(%[^{}]+)?}/) do |_m|
      variable = Regexp.last_match(1)
      format = Regexp.last_match(2)
      value = champ_value(object_values(@source, variable)&.first)
      value = format.blank? ? value.to_s : format % value
      block_given? ? yield(value) : value
    end
  end

  def instanciate_filename(template)
    return 'document.pdf' if template.blank?

    instanciate(template) do |value|
      value.gsub(/[^- 0-9a-z\u00C0-\u017F.]/i, '_')
    end
  end
end
