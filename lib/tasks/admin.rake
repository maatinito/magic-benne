# frozen_string_literal: true

namespace :admin do
  desc 'Export CSVs anonymising first name & last names'
  task export: :environment do
    files = Dir.glob('export1/**/*.csv')
    zipfile_name = 'mb.zip'
    dic = {}
    count = 0
    Zip::File.open(zipfile_name, create: true) do |zipfile|
      files.each do |input|
        table = CSV.read(input, headers: true, col_sep: ';')
        table.each do |row|
          row.each do |key, value|
            puts "key ignored #{key}" unless key.match?(/Nom\b|nom_marital|prénom|dn|activite|téléphone|naissance|raison|adresse|fonction/i)
            next unless value.present? && key.match?(/Nom\b|nom_marital|prénom|dn|activité|téléphone|naissance|raison|adresse|fonction/i)

            row[key] = if dic[value].present?
                         dic[value]
                       elsif value.is_a?(Date) || key.match?(/date/i)
                         value = Date.parse(value) if value.is_a?(String)
                         dic[value] = value.beginning_of_year
                       elsif key.is_a?(Integer) || key.match?(/téléphone/i)
                         dic[value] = (87_000_000 + (count += 1)).to_s
                       else
                         dic[value] = "#{key} #{count += 1}"
                       end
          end
        end
        zipfile.get_output_stream(input) { |f| f.write(table.to_csv) }
        puts "#{input} added"
      end
    end
  end
end
