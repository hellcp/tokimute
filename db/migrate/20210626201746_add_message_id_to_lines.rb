class AddMessageIdToLines < ActiveRecord::Migration[6.1]
  def change
    add_column :lines, :message_id, :integer
  end
  add_index :lines, :message_id
end
