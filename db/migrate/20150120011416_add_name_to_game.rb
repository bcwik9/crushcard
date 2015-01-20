class AddNameToGame < ActiveRecord::Migration
  def change
    add_column :games, :name, :string
  end
end
