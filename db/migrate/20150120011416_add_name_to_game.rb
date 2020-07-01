class AddNameToGame < ActiveRecord::Migration[4.2]
  def change
    add_column :games, :name, :string
  end
end
