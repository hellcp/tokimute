class CreateUser < ActiveRecord::Migration[6.1]
  def change
    create_table :users do |t|
      t.integer :discord_id
      t.boolean :accepted_license
    end
    add_index :users, :discord_id
  end
end
