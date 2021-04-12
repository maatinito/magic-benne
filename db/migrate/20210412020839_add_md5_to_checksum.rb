class AddMd5ToChecksum < ActiveRecord::Migration[6.0]
  def change
    add_column :checksums, :md5, :string
    add_index :checksums, :md5
  end
end
