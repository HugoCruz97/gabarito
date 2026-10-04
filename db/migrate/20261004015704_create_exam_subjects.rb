class CreateExamSubjects < ActiveRecord::Migration[8.1]
  def change
    create_table :exam_subjects do |t|
      t.references :exam, null: false, foreign_key: { on_delete: :cascade }
      t.references :subject, null: false, foreign_key: true
      t.integer :position, null: false, default: 0
      t.integer :questions_count, null: false
      t.decimal :points_per_question, precision: 6, scale: 2, null: false

      t.timestamps
    end
  end
end
