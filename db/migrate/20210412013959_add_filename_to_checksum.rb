class AddFilenameToChecksum < ActiveRecord::Migration[6.0]
  def change
    add_column :checksums, :filename, :string
  end
end
