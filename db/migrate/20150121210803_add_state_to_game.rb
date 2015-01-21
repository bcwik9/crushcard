class AddStateToGame < ActiveRecord::Migration
  def change
    add_column :games, :state, :text
  end
end
