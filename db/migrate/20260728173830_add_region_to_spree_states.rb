class AddRegionToSpreeStates < ActiveRecord::Migration[8.1]
  def change
    add_column :spree_states, :region, :string
    add_index :spree_states, :region
  end
end
