# frozen_string_literal: true

module Cis
  class ExportSheet < ExportExcel
    def version
      super + 2
    end

    def required_fields
      super + %i[colonnes fichier]
    end

    def authorized_fields
      super + %i[feuille variables]
    end

    private

    def save_sheet(sheet_name, sheet)
      @field_source = FieldSource.new(@dossier, variables(sheet))
      super
    end

    def variables(sheet)
      variables = @params[:variables]
      return {} if variables.blank?

      variables.reduce({}) do |h, (key, reference)|
        if (m = /^([A-Z]+)([0-9]+)$/i.match(reference))
          h[key] = sheet.cell(m[1], m[2].to_i)
          h
        else
          throw ExportError.new("Invalid Excel reference #{reference} for variable #{key}. it should respect the syntax {Letter}+{Digit}+ (example: C3).")
        end
      end
    end

    def title_regexps
      definitions.to_h { |d| [d[0], d[2]] }
    end

    def definitions
      @definitions ||= @params[:colonnes].map(&method(:definition))
    end

    def definition(param)
      if param.is_a?(Hash)
        par_defaut = param['par_defaut'] || ''
        field = param['colonne']
        regexp = Regexp.new(param['regexp'] || Regexp.quote(field), Regexp::IGNORECASE)
      else
        field = param.to_s
        par_defaut = ''
        regexp = Regexp.new(Regexp.quote(field), Regexp::IGNORECASE)
      end
      [field, par_defaut, regexp]
    end

    def sheet_regexp
      @params[:feuille]
    end

    def output_path(_sheet_name)
      path = "#{output_dir}/#{StringTemplate.new(@field_source).instanciate_filename(@params[:fichier])}"
      FileUtils.mkpath(File.dirname(path))
      path
    end

    # def normalize_line(line)
    #   super
    #   definitions.reduce({}) do |hash, definition|
    #     column, default_value = definition
    #     hash[column] = line[column].presence || default_value
    #     hash
    #   end
    # end
  end
end
