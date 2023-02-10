# frozen_string_literal: true

require 'active_support/core_ext/date/calculations'

namespace :dbs do
  desc 'Display dates between start and end'
  task :ships, [:start_date, :path] do |_t, args|
    start_date = (args[:start_date] || 10.days.ago.strftime('%d/%m/%Y')).gsub('/', '%2F')
    output = args[:path] || 'ships.csv'

    url = "https://www.portdepapeete.pf/fr/previsions-navires?field_date_prev_value%5Bvalue%5D%5Bdate%5D=#{start_date}&field_navire_value="
    response = Typhoeus.get(url, timeout: 30, ssl_verifypeer: true, verbose: false)
    page = Nokogiri::HTML(response.body)

    table = page.css('table').first

    if table
      rows = table.css('tr')
      data = rows.map do |row|
        row.css('th, td').map(&:text)
      end
      CSV.open(output, 'w') do |csv|
        old_key = ''
        data.each do |row|
          key = "#{row[1]}\t#{row[7]}\t#{row[0]}"
          next unless old_key != key

          csv << row
          puts "#{row[1].ljust(20)}\t#{row[7].ljust(10)}\t#{row[0]}\t#{row[6]}" if row[3].include?('CARGO') && row[4].present? # if cargo && arrival
          old_key = key
        end
      end

      puts "Table extracted and saved to #{output}"
    else
      puts 'No table found on the page'
    end
  end
end
