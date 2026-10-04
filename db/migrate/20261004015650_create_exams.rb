class CreateExams < ActiveRecord::Migration[8.1]
  def change
    create_table :exams do |t|
      t.string :title, null: false
      t.date :applied_on
      t.integer :options_count, null: false, default: 5

      t.timestamps
    end
  end
end
