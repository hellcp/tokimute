class CreateLine < ActiveRecord::Migration[6.1]
  def change
    create_table :lines do |t|
      t.string :content
    end
    add_reference :lines, :post, foreign_key: true
  end
end
