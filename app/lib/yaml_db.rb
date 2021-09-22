# frozen_string_literal: true

# Patch YamlDb to work with foreign keys and to dump empty tables
module YamlDb
  class Load
    # Monkey path to reorder truncatation and table loads to respect foreign key dependencies
    def self.load_documents(io, truncate = true)
      yall = {}
      YAML.load_stream(io) do |ydoc|
        yall.merge!(ydoc)
      end

      unordered_tables = yall.keys.reject do |table|
        %w[ar_internal_metadata schema_info schema_migrations].include?(table)
      end.sort
      tables = []
      while unordered_tables.any?
        loadable_tables = unordered_tables.find_all do |table|
          foreign_keys = ActiveRecord::Base.connection.foreign_keys(table)
          foreign_keys.reject { |foreign_key| tables.include?(foreign_key.to_table) }.empty?
        end

        abort("Unable to sequence the following tables for loading: #{unordered_tables.join(', ')}") if loadable_tables.empty?

        tables += loadable_tables
        unordered_tables -= loadable_tables
      end

      if truncate == true
        tables.reverse.each do |table|
          truncate_table(table)
        end
      end

      tables.each do |table|
        next if yall[table].nil?

        load_table(table, yall[table], truncate)
      end
    end
  end

  module SerializationHelper
    class Load
      # Monkey patch to use a SAVEPOINT so that the fallback to DELETE FROM actually works!
      def self.truncate_table(table)
        ActiveRecord::Base.connection.execute('SAVEPOINT before_truncation')
        ActiveRecord::Base.connection.execute("TRUNCATE #{Utils.quote_table(table)} CASCADE")
      rescue Exception
        ActiveRecord::Base.connection.execute('ROLLBACK TO SAVEPOINT before_truncation')
        ActiveRecord::Base.connection.execute("DELETE FROM #{Utils.quote_table(table)}")
      end

      # Monkey patch to enable successful load when empty record set
      def self.load_records(table, column_names, records)
        return if records.nil?
        return if column_names.nil?

        quoted_column_names = column_names.map do |column|
          ActiveRecord::Base.connection.quote_column_name(column)
        end.join(',')
        quoted_table_name = Utils.quote_table(table)
        records.each do |record|
          quoted_values = record.map { |c| ActiveRecord::Base.connection.quote(c) }.join(',')
          ActiveRecord::Base.connection.execute("INSERT INTO #{quoted_table_name} (#{quoted_column_names}) VALUES (#{quoted_values})")
        end
      end
    end

    class Dump
      # Monkey patch to dump empty tables, otherwise they won't get purged on restore!
      def self.dump_table(io, table)
        dump_table_columns(io, table)
        dump_table_records(io, table)
        puts 'MonkeyPatch !'
      end

      # Monkey patch to exclude ar_internal_metadata from the table list as well
      def self.tables
        puts 'MonkeyPatch !'
        ActiveRecord::Base.connection.tables.reject do |table|
          %w[ar_internal_metadata schema_info schema_migrations].include?(table)
        end.sort
      end
    end
  end
end
