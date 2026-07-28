class AddRutToSpreeUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :spree_users, :rut, :string
    add_index :spree_users, :rut, unique: true
  end
end
