class CreateStudents < ActiveRecord::Migration[8.1]
  def change
    create_table :students do |t|
      t.string :name, null: false
      t.string :registration_number
      t.references :classroom, null: false, foreign_key: true

      t.timestamps
    end
    add_index :students, :registration_number, unique: true
  end
end
