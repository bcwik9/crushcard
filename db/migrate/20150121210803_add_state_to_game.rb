class AddStateToGame < ActiveRecord::Migration[4.2]
  def change
    add_column :games, :state, :text
  end
end
