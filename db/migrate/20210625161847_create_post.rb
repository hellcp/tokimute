class CreatePost < ActiveRecord::Migration[6.1]
  def change
    create_table :posts do |t|
      t.string :name
    end
    add_reference :posts, :user, foreign_key: true
  end
end
